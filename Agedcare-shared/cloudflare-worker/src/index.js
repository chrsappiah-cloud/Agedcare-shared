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
          },
        },
        200,
        request,
        env
      );
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
