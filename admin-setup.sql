-- TASKI administrator access setup
-- Run once in Supabase SQL Editor. This grants admin access only to the
-- existing account whose email is kuriap269@gmail.com.

create table if not exists public.taski_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.taski_admins enable row level security;

drop policy if exists "Admins can view their own admin record" on public.taski_admins;
create policy "Admins can view their own admin record"
  on public.taski_admins for select
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.is_taski_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.taski_admins
    where user_id = auth.uid()
  );
$$;

grant execute on function public.is_taski_admin() to authenticated;

drop policy if exists "TASKI admins can view all profiles" on public.profiles;
create policy "TASKI admins can view all profiles"
  on public.profiles for select
  to authenticated
  using (public.is_taski_admin());

drop policy if exists "TASKI admins can view all memberships" on public.memberships;
create policy "TASKI admins can view all memberships"
  on public.memberships for select
  to authenticated
  using (public.is_taski_admin());

drop policy if exists "TASKI admins can update memberships" on public.memberships;
create policy "TASKI admins can update memberships"
  on public.memberships for update
  to authenticated
  using (public.is_taski_admin())
  with check (public.is_taski_admin());

-- Add the existing administrator account. This inserts nothing if the email
-- is not yet present in Supabase Auth; confirm the account exists first.
insert into public.taski_admins (user_id)
select id
from auth.users
where lower(email) = lower('kuriap269@gmail.com')
on conflict (user_id) do nothing;
