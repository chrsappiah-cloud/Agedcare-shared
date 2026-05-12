const SUPABASE_PATH_PREFIXES = [
  "/auth/v1/",
  "/rest/v1/",
  "/storage/v1/",
  "/functions/v1/",
  "/realtime/v1/",
  "/realtime/v2/",
];

const PRIMARY_PATH_PREFIXES = [
  "/facility",
  "/ai/",
];

const APPLE_VERIFY_RECEIPT_URL = "https://buy.itunes.apple.com/verifyReceipt";
const APPLE_SANDBOX_VERIFY_RECEIPT_URL = "https://sandbox.itunes.apple.com/verifyReceipt";
const PRODUCT_TIER_BY_ID = {
  "wcs.Agedcare_shared.care_pro_monthly": "care_pro",
  "wcs.Agedcare_shared.care_team_annual": "care_team",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: corsHeaders(request, env),
      });
    }

    if (url.pathname === "/healthz") {
      return json(
        {
          ok: true,
          provider: "cloudflare-worker",
          routes: {
            supabase: Boolean(env.SUPABASE_URL),
            primaryApi: Boolean(env.PRIMARY_API_URL),
            aiApi: Boolean(env.AI_API_URL),
            subscriptionValidation: Boolean(env.APPLE_SHARED_SECRET),
          },
        },
        200,
        request,
        env
      );
    }

    if (url.pathname === "/billing/validate-receipt") {
      return handleReceiptValidation(request, env);
    }

    const upstreamBaseURL = resolveUpstream(url.pathname, env);
    if (!upstreamBaseURL) {
      return json(
        {
          ok: false,
          error: "No upstream configured for this route.",
          path: url.pathname,
        },
        503,
        request,
        env
      );
    }

    const upstreamURL = new URL(upstreamBaseURL);
    upstreamURL.pathname = normalizePath(url.pathname);
    upstreamURL.search = url.search;

    const headers = new Headers(request.headers);
    headers.set("x-forwarded-host", url.host);
    headers.set("x-forwarded-proto", url.protocol.replace(":", ""));
    headers.set("x-edge-provider", "cloudflare");

    if (shouldUseSupabase(url.pathname) && env.SUPABASE_ANON_KEY && !headers.has("apikey")) {
      headers.set("apikey", env.SUPABASE_ANON_KEY);
    }

    const upstreamRequest = new Request(upstreamURL.toString(), {
      method: request.method,
      headers,
      body: shouldSendBody(request.method) ? request.body : undefined,
      redirect: "follow",
    });

    const response = await fetch(upstreamRequest);
    return withCors(response, request, env);
  },
};

async function handleReceiptValidation(request, env) {
  if (request.method !== "POST") {
    return json(
      {
        valid: false,
        isActive: false,
        status: 405,
        message: "Use POST for receipt validation.",
      },
      405,
      request,
      env
    );
  }

  if (!env.APPLE_SHARED_SECRET) {
    return json(
      {
        valid: false,
        isActive: false,
        status: 503,
        message: "Subscription validation is not configured.",
      },
      503,
      request,
      env
    );
  }

  let payload;
  try {
    payload = await request.json();
  } catch {
    return json(
      {
        valid: false,
        isActive: false,
        status: 400,
        message: "Invalid receipt payload.",
      },
      400,
      request,
      env
    );
  }

  const receiptData = typeof payload?.receiptData === "string" ? payload.receiptData.trim() : "";
  if (!receiptData) {
    return json(
      {
        valid: false,
        isActive: false,
        status: 400,
        message: "Receipt data is required.",
      },
      400,
      request,
      env
    );
  }

  let verification = await verifyReceiptWithApple(receiptData, env, APPLE_VERIFY_RECEIPT_URL);
  if (verification.status === 21007) {
    verification = await verifyReceiptWithApple(receiptData, env, APPLE_SANDBOX_VERIFY_RECEIPT_URL);
  }

  const entitlement = resolveEntitlement(verification);
  const normalized = {
    valid: verification.status === 0,
    isActive: entitlement.isActive,
    status: verification.status,
    environment: verification.environment || null,
    currentTier: entitlement.currentTier,
    productID: entitlement.productID,
    expiresAt: entitlement.expiresAt,
    message:
      verification.status === 0
        ? entitlement.isActive
          ? "Subscription validated."
          : "Receipt validated without an active paid subscription."
        : "Receipt validation failed.",
  };

  return json(normalized, verification.status === 0 ? 200 : 422, request, env);
}

async function verifyReceiptWithApple(receiptData, env, endpoint) {
  const response = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
    },
    body: JSON.stringify({
      "receipt-data": receiptData,
      password: env.APPLE_SHARED_SECRET,
      "exclude-old-transactions": true,
    }),
  });

  if (!response.ok) {
    return {
      status: response.status,
      environment: null,
      receipt: null,
    };
  }

  return response.json();
}

function resolveEntitlement(verification) {
  const candidates = collectCandidates(verification);
  const now = Date.now();
  const active = candidates
    .filter((candidate) => candidate.currentTier && candidate.expiresAtMs && candidate.expiresAtMs > now)
    .sort((left, right) => right.expiresAtMs - left.expiresAtMs)[0];

  if (!active) {
    return {
      isActive: false,
      currentTier: null,
      productID: null,
      expiresAt: null,
    };
  }

  return {
    isActive: true,
    currentTier: active.currentTier,
    productID: active.productID,
    expiresAt: new Date(active.expiresAtMs).toISOString(),
  };
}

function collectCandidates(verification) {
  const latestReceiptInfo = Array.isArray(verification?.latest_receipt_info)
    ? verification.latest_receipt_info
    : [];
  const inApp = Array.isArray(verification?.receipt?.in_app) ? verification.receipt.in_app : [];

  return [...latestReceiptInfo, ...inApp]
    .map((entry) => {
      const productID = typeof entry?.product_id === "string" ? entry.product_id : null;
      const currentTier = productID ? PRODUCT_TIER_BY_ID[productID] || null : null;
      const expiresAtMs = parseMilliseconds(entry?.expires_date_ms);

      return {
        currentTier,
        productID,
        expiresAtMs,
      };
    })
    .filter((entry) => entry.currentTier);
}

function parseMilliseconds(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  if (typeof value === "string" && value.trim()) {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : null;
  }

  return null;
}

function resolveUpstream(pathname, env) {
  if (shouldUseSupabase(pathname)) {
    return env.SUPABASE_URL;
  }

  if (pathname.startsWith("/ai/")) {
    return env.AI_API_URL || env.PRIMARY_API_URL || env.SUPABASE_URL;
  }

  if (PRIMARY_PATH_PREFIXES.some((prefix) => pathname === prefix || pathname.startsWith(prefix))) {
    return env.PRIMARY_API_URL || env.SUPABASE_URL;
  }

  return env.PRIMARY_API_URL || env.SUPABASE_URL;
}

function shouldUseSupabase(pathname) {
  return SUPABASE_PATH_PREFIXES.some((prefix) => pathname.startsWith(prefix));
}

function normalizePath(pathname) {
  return pathname.startsWith("/") ? pathname : `/${pathname}`;
}

function shouldSendBody(method) {
  return method !== "GET" && method !== "HEAD";
}

function withCors(response, request, env) {
  const headers = new Headers(response.headers);
  for (const [key, value] of Object.entries(corsHeaders(request, env))) {
    headers.set(key, value);
  }

  headers.set("x-edge-provider", "cloudflare");

  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

function corsHeaders(request, env) {
  const origin = request.headers.get("Origin");
  const configured = (env.ALLOWED_ORIGINS || "*")
    .split(",")
    .map((value) => value.trim())
    .filter(Boolean);

  const allowOrigin =
    configured.includes("*")
      ? "*"
      : configured.includes(origin)
        ? origin
        : configured[0] || "*";

  return {
    "Access-Control-Allow-Origin": allowOrigin,
    "Access-Control-Allow-Methods": "GET,POST,PUT,PATCH,DELETE,OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, apikey, x-client-info",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

function json(payload, status, request, env) {
  return new Response(JSON.stringify(payload, null, 2), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders(request, env),
    },
  });
}
