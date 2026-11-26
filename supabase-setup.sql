-- TASKI member profile and membership tables
-- Run this script once in Supabase Dashboard > SQL Editor > New query.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  phone text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.memberships (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan text not null default 'Monthly',
  status text not null default 'pending'
    check (status in ('pending', 'active', 'expired', 'cancelled')),
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists memberships_user_id_idx
  on public.memberships(user_id);

alter table public.profiles enable row level security;
alter table public.memberships enable row level security;

drop policy if exists "Members can view own profile" on public.profiles;
create policy "Members can view own profile"
  on public.profiles for select
  to authenticated
  using (auth.uid() = id);

drop policy if exists "Members can add own profile" on public.profiles;
create policy "Members can add own profile"
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

drop policy if exists "Members can update own profile" on public.profiles;
create policy "Members can update own profile"
  on public.profiles for update
  to authenticated
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "Members can view own membership" on public.memberships;
create policy "Members can view own membership"
  on public.memberships for select
  to authenticated
  using (auth.uid() = user_id);

-- Automatically create a profile row whenever a new auth account is created.
create or replace function public.handle_new_taski_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_taski_auth_user_created on auth.users;
create trigger on_taski_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_taski_user();
