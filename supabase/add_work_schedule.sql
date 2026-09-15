-- ZA OBSTOJEČ PROJEKT: zaženite enkrat v Supabase SQL Editorju.
create table if not exists public.work_schedules (
  work_date date primary key,
  sale_start time,
  sale_end time,
  is_closed boolean not null default false,
  updated_at timestamptz not null default now(),
  check ((is_closed and sale_start is null and sale_end is null) or (not is_closed and sale_start is not null and sale_end is not null and sale_end > sale_start))
);
create table if not exists public.work_schedule_workers (
  work_date date not null references public.work_schedules(work_date) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  primary key (work_date, profile_id)
);
alter table public.work_schedules enable row level security;
alter table public.work_schedule_workers enable row level security;
create policy "work schedules admin manage" on public.work_schedules for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "work schedule workers admin manage" on public.work_schedule_workers for all to authenticated using (public.is_admin()) with check (public.is_admin());
