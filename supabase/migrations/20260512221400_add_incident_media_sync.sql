create table if not exists public.incident_media (
    id uuid primary key,
    facility_id uuid not null references public.facilities (id) on delete cascade,
    resident_id uuid references public.residents (id) on delete set null,
    incident_type text not null,
    recorded_at timestamptz not null,
    duration_seconds double precision not null default 0,
    local_filename text not null,
    snapshot_filename text,
    external_media_url text,
    analysis_id text,
    summary text,
    cloudkit_record_name text,
    sync_status text not null default 'pendingUpload',
    metadata jsonb not null default '{}'::jsonb,
    synced_at timestamptz,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint incident_media_sync_status_check check (sync_status in ('localOnly', 'pendingUpload', 'synced', 'failed'))
);

create index if not exists idx_incident_media_facility_recorded_at
    on public.incident_media (facility_id, recorded_at desc);
create index if not exists idx_incident_media_resident_recorded_at
    on public.incident_media (resident_id, recorded_at desc);

alter table public.incident_media enable row level security;

drop policy if exists "facility incident media read" on public.incident_media;
create policy "facility incident media read"
on public.incident_media
for select
to authenticated
using (facility_id = public.current_staff_facility_id());

create or replace function public.upsert_incident_media(
    p_incident_id uuid,
    p_facility_id uuid,
    p_resident_id uuid default null,
    p_incident_type text default 'incident',
    p_recorded_at timestamptz default now(),
    p_duration_seconds double precision default 0,
    p_local_filename text default '',
    p_snapshot_filename text default null,
    p_external_media_url text default null,
    p_analysis_id text default null,
    p_summary text default null,
    p_cloudkit_record_name text default null,
    p_sync_status text default 'pendingUpload',
    p_metadata jsonb default '{}'::jsonb
)
returns table (
    incident_id text,
    synced_at text,
    external_media_url text,
    cloudkit_record_name text
)
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.incident_media (
        id,
        facility_id,
        resident_id,
        incident_type,
        recorded_at,
        duration_seconds,
        local_filename,
        snapshot_filename,
        external_media_url,
        analysis_id,
        summary,
        cloudkit_record_name,
        sync_status,
        metadata,
        synced_at,
        updated_at
    )
    values (
        p_incident_id,
        p_facility_id,
        p_resident_id,
        p_incident_type,
        coalesce(p_recorded_at, now()),
        greatest(coalesce(p_duration_seconds, 0), 0),
        coalesce(nullif(p_local_filename, ''), p_incident_id::text || '.mov'),
        p_snapshot_filename,
        p_external_media_url,
        p_analysis_id,
        p_summary,
        p_cloudkit_record_name,
        coalesce(p_sync_status, 'pendingUpload'),
        coalesce(p_metadata, '{}'::jsonb),
        case
            when coalesce(p_sync_status, 'pendingUpload') = 'synced' then now()
            else null
        end,
        now()
    )
    on conflict (id) do update
    set resident_id = excluded.resident_id,
        incident_type = excluded.incident_type,
        recorded_at = excluded.recorded_at,
        duration_seconds = excluded.duration_seconds,
        local_filename = excluded.local_filename,
        snapshot_filename = excluded.snapshot_filename,
        external_media_url = coalesce(excluded.external_media_url, public.incident_media.external_media_url),
        analysis_id = coalesce(excluded.analysis_id, public.incident_media.analysis_id),
        summary = coalesce(excluded.summary, public.incident_media.summary),
        cloudkit_record_name = coalesce(excluded.cloudkit_record_name, public.incident_media.cloudkit_record_name),
        sync_status = excluded.sync_status,
        metadata = coalesce(excluded.metadata, public.incident_media.metadata),
        synced_at = case
            when excluded.sync_status = 'synced' then now()
            else public.incident_media.synced_at
        end,
        updated_at = now();

    return query
    select
        im.id::text,
        case
            when im.synced_at is null then null
            else to_char(im.synced_at at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
        end,
        im.external_media_url,
        im.cloudkit_record_name
    from public.incident_media im
    where im.id = p_incident_id;
end;
$$;

grant execute on function public.upsert_incident_media(
    uuid,
    uuid,
    uuid,
    text,
    timestamptz,
    double precision,
    text,
    text,
    text,
    text,
    text,
    text,
    text,
    jsonb
) to anon, authenticated;
