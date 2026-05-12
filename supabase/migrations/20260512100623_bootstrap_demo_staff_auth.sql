create table if not exists public.staff_access_bootstrap (
    email text primary key,
    facility_id uuid not null references public.facilities (id) on delete cascade,
    role text not null,
    display_name text not null,
    subscription_tier text not null default 'starter',
    beta_track text not null default 'care',
    is_demo boolean not null default false,
    constraint staff_access_bootstrap_role_check check (role in ('creator', 'admin', 'administrator', 'tester', 'nurse', 'carer', 'caregiver')),
    constraint staff_access_bootstrap_subscription_check check (subscription_tier in ('starter', 'carePro', 'careTeam'))
);

insert into public.staff_access_bootstrap (email, facility_id, role, display_name, subscription_tier, beta_track, is_demo)
values
    ('christopher.appiahthompson@myworldclass.org', '99999999-1111-4111-8111-111111111111', 'creator', 'Dr Christopher Appiah-Thompson', 'careTeam', 'care', false),
    ('admin@gvcare.com', '99999999-2222-4222-8222-222222222222', 'admin', 'Dr Sarah Chen', 'careTeam', 'care', true),
    ('nurse@gvcare.com', '99999999-3333-4333-8333-333333333333', 'nurse', 'John Smith', 'careTeam', 'care', true),
    ('carer@gvcare.com', '99999999-4444-4444-8444-444444444444', 'carer', 'Emma Davis', 'carePro', 'care', true),
    ('teamtester@gvcare.com', '99999999-3333-4333-8333-333333333333', 'tester', 'John Smith', 'careTeam', 'care', false),
    ('protester@gvcare.com', '99999999-4444-4444-8444-444444444444', 'tester', 'Emma Davis', 'carePro', 'care', false),
    ('startertester@gvcare.com', '99999999-5555-4555-8555-555555555555', 'tester', 'Family Carer Preview', 'starter', 'care', false)
on conflict (email) do update
set facility_id = excluded.facility_id,
    role = excluded.role,
    display_name = excluded.display_name,
    subscription_tier = excluded.subscription_tier,
    beta_track = excluded.beta_track,
    is_demo = excluded.is_demo;

create or replace function public.bootstrap_staff_profile()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
declare
    mapping public.staff_access_bootstrap%rowtype;
begin
    select *
    into mapping
    from public.staff_access_bootstrap
    where email = lower(new.email);

    if not found then
        return new;
    end if;

    update auth.users
    set email_confirmed_at = coalesce(email_confirmed_at, now())
    where id = new.id;

    insert into public.staff_profiles (
        id,
        facility_id,
        role,
        display_name,
        subscription_tier,
        beta_track,
        is_demo
    )
    values (
        new.id,
        mapping.facility_id,
        mapping.role,
        mapping.display_name,
        mapping.subscription_tier,
        mapping.beta_track,
        mapping.is_demo
    )
    on conflict (id) do update
    set facility_id = excluded.facility_id,
        role = excluded.role,
        display_name = excluded.display_name,
        subscription_tier = excluded.subscription_tier,
        beta_track = excluded.beta_track,
        is_demo = excluded.is_demo;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created_bootstrap_staff_profile on auth.users;
create trigger on_auth_user_created_bootstrap_staff_profile
after insert on auth.users
for each row
execute function public.bootstrap_staff_profile();

with matched_users as (
    select
        u.id,
        b.facility_id,
        b.role,
        b.display_name,
        b.subscription_tier,
        b.beta_track,
        b.is_demo
    from auth.users u
    join public.staff_access_bootstrap b
      on b.email = lower(u.email)
)
insert into public.staff_profiles (
    id,
    facility_id,
    role,
    display_name,
    subscription_tier,
    beta_track,
    is_demo
)
select
    id,
    facility_id,
    role,
    display_name,
    subscription_tier,
    beta_track,
    is_demo
from matched_users
on conflict (id) do update
set facility_id = excluded.facility_id,
    role = excluded.role,
    display_name = excluded.display_name,
    subscription_tier = excluded.subscription_tier,
    beta_track = excluded.beta_track,
    is_demo = excluded.is_demo;

update auth.users u
set email_confirmed_at = coalesce(u.email_confirmed_at, now())
from public.staff_access_bootstrap b
where b.email = lower(u.email)
  and u.email_confirmed_at is null;
