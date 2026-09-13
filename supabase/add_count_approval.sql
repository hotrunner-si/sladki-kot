-- ZA OBSTOJEČ PROJEKT: zaženite enkrat v Supabase SQL Editorju.
-- Doda oddajo, administratorsko potrditev, obnovljive osnutke in prisotnost na strani popisa.

alter table public.inventory_counts drop constraint if exists inventory_counts_status_check;
alter table public.inventory_counts drop constraint if exists completed_count_has_time;
alter table public.inventory_counts add column if not exists updated_at timestamptz not null default now();
alter table public.inventory_counts add column if not exists active_until timestamptz;
alter table public.inventory_counts add column if not exists submitted_at timestamptz;
alter table public.inventory_counts add column if not exists submitted_by uuid references auth.users(id) on delete set null;
alter table public.inventory_counts add column if not exists last_edited_by uuid references auth.users(id) on delete set null default auth.uid();
update public.inventory_counts set last_edited_by = created_by where last_edited_by is null;
alter table public.inventory_counts add constraint inventory_counts_status_check check (status in ('draft','incomplete','submitted','completed'));

create or replace function public.touch_inventory_count() returns trigger language plpgsql security definer set search_path = public as $$
begin
  update public.inventory_counts set updated_at = now() where id = new.inventory_count_id;
  return new;
end $$;
drop trigger if exists count_items_touch_parent on public.inventory_count_items;
create trigger count_items_touch_parent after insert or update on public.inventory_count_items for each row execute function public.touch_inventory_count();

create or replace function public.expire_inventory_drafts() returns void language plpgsql security definer set search_path = public as $$
begin
  update public.inventory_counts set status = 'incomplete', active_until = null
  where status = 'draft'
    and ((active_until is not null and active_until < now()) or (active_until is null and updated_at < now() - interval '10 minutes'));
end $$;
grant execute on function public.expire_inventory_drafts() to authenticated;

drop policy if exists "profiles authenticated names read" on public.profiles;
create policy "profiles authenticated names read" on public.profiles for select to authenticated using (true);

drop policy if exists "counts admin read" on public.inventory_counts;
drop policy if exists "counts own draft read" on public.inventory_counts;
drop policy if exists "counts own read" on public.inventory_counts;
drop policy if exists "counts update own draft" on public.inventory_counts;
drop policy if exists "counts visible read" on public.inventory_counts;
drop policy if exists "counts update workflow" on public.inventory_counts;
create policy "counts visible read" on public.inventory_counts for select to authenticated using (public.is_admin() or created_by = auth.uid() or last_edited_by = auth.uid() or status <> 'draft');
create policy "counts update workflow" on public.inventory_counts for update to authenticated using (public.is_admin() or (last_edited_by = auth.uid() and status = 'draft') or status = 'incomplete') with check (public.is_admin() or (last_edited_by = auth.uid() and status in ('draft','submitted')));
drop policy if exists "counts delete own draft" on public.inventory_counts;
drop policy if exists "counts delete own open" on public.inventory_counts;
create policy "counts delete own open" on public.inventory_counts for delete to authenticated using (public.is_admin() or (last_edited_by = auth.uid() and status in ('draft','incomplete')));

drop policy if exists "count items admin read" on public.inventory_count_items;
drop policy if exists "count items own draft read" on public.inventory_count_items;
drop policy if exists "count items own read" on public.inventory_count_items;
drop policy if exists "count items visible read" on public.inventory_count_items;
create policy "count items visible read" on public.inventory_count_items for select to authenticated using (exists(select 1 from public.inventory_counts c where c.id = inventory_count_id and (public.is_admin() or c.created_by = auth.uid() or c.last_edited_by = auth.uid() or c.status <> 'draft')));
drop policy if exists "count items own draft write" on public.inventory_count_items;
drop policy if exists "count items own draft update" on public.inventory_count_items;
create policy "count items own draft write" on public.inventory_count_items for insert to authenticated with check (exists(select 1 from public.inventory_counts c where c.id = inventory_count_id and c.last_edited_by = auth.uid() and c.status = 'draft'));
create policy "count items own draft update" on public.inventory_count_items for update to authenticated using (exists(select 1 from public.inventory_counts c where c.id = inventory_count_id and c.last_edited_by = auth.uid() and c.status = 'draft')) with check (exists(select 1 from public.inventory_counts c where c.id = inventory_count_id and c.last_edited_by = auth.uid() and c.status = 'draft'));
