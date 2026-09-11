-- Sladki kot: zaženite v Supabase SQL Editorju kot en skript.
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'inventory' check (role in ('admin','inventory')),
  created_at timestamptz not null default now()
);
create table public.suppliers (
  id uuid primary key default gen_random_uuid(), name text not null unique,
  default_lead_time_days integer not null default 2 check (default_lead_time_days >= 0), contact text, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.products (
  id uuid primary key default gen_random_uuid(), name text not null, category text not null, unit text not null,
  supplier_id uuid references public.suppliers(id) on delete restrict, lead_time_days integer check (lead_time_days >= 0),
  safety_stock_days integer not null default 1 check (safety_stock_days >= 0), active boolean not null default true,
  counting_unit text, alternative_unit text, alternative_unit_size numeric(12,3) check (alternative_unit_size > 0),
  count_step numeric(12,3) not null default 1 check (count_step > 0),
  sort_order integer not null default 0, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.inventory_counts (
  id uuid primary key default gen_random_uuid(), created_by uuid references auth.users(id) on delete set null default auth.uid(),
  started_at timestamptz not null default now(), completed_at timestamptz, status text not null default 'draft' check(status in ('draft','completed')),
  notes text, constraint completed_count_has_time check ((status = 'draft' and completed_at is null) or (status = 'completed' and completed_at is not null))
);
create table public.inventory_count_items (
  id uuid primary key default gen_random_uuid(), inventory_count_id uuid not null references public.inventory_counts(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict, quantity numeric(12,3) not null check(quantity >= 0),
  unique(inventory_count_id, product_id)
);
create table public.deliveries (
  id uuid primary key default gen_random_uuid(), supplier_id uuid not null references public.suppliers(id) on delete restrict,
  delivery_date date not null default current_date, created_by uuid references auth.users(id) on delete set null default auth.uid(), notes text,
  created_at timestamptz not null default now()
);
create table public.delivery_items (
  id uuid primary key default gen_random_uuid(), delivery_id uuid not null references public.deliveries(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete restrict, quantity numeric(12,3) not null check(quantity > 0),
  unique(delivery_id, product_id)
);
create index products_supplier_idx on public.products(supplier_id); create index products_active_idx on public.products(active);
create index counts_completed_idx on public.inventory_counts(completed_at desc) where status = 'completed';
create index count_items_product_idx on public.inventory_count_items(product_id); create index deliveries_date_idx on public.deliveries(delivery_date desc);
create index delivery_items_product_idx on public.delivery_items(product_id);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end $$;
create trigger suppliers_updated before update on public.suppliers for each row execute function public.set_updated_at();
create trigger products_updated before update on public.products for each row execute function public.set_updated_at();
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path = public as $$ select exists(select 1 from public.profiles where id = auth.uid() and role = 'admin') $$;

alter table public.profiles enable row level security; alter table public.suppliers enable row level security; alter table public.products enable row level security;
alter table public.inventory_counts enable row level security; alter table public.inventory_count_items enable row level security;
alter table public.deliveries enable row level security; alter table public.delivery_items enable row level security;
-- Profiles: vsak lahko prebere svoj profil; administrator vse profile.
create policy "profiles own or admin read" on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy "profiles admin manage" on public.profiles for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- Poslovni šifranti: zaposlenemu je dovoljen samo ogled aktivnih artiklov.
create policy "suppliers admin manage" on public.suppliers for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "products active read" on public.products for select to authenticated using (active or public.is_admin());
create policy "products admin manage" on public.products for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- Popisi: zaposleni lahko ustvarja in spreminja izključno svoj osnutek; zaključka ne more več odpreti za urejanje.
create policy "counts admin read" on public.inventory_counts for select to authenticated using (public.is_admin());
create policy "counts own draft read" on public.inventory_counts for select to authenticated using (created_by = auth.uid() and status = 'draft');
create policy "counts create own" on public.inventory_counts for insert to authenticated with check (created_by = auth.uid());
create policy "counts update own draft" on public.inventory_counts for update to authenticated using (public.is_admin() or (created_by = auth.uid() and status = 'draft')) with check (public.is_admin() or (created_by = auth.uid() and status in ('draft','completed')));
create policy "counts delete own draft" on public.inventory_counts for delete to authenticated using (public.is_admin() or (created_by = auth.uid() and status = 'draft'));
create policy "count items admin read" on public.inventory_count_items for select to authenticated using (public.is_admin());
create policy "count items own draft read" on public.inventory_count_items for select to authenticated using (exists(select 1 from public.inventory_counts c where c.id = inventory_count_id and c.created_by = auth.uid() and c.status = 'draft'));
create policy "count items own draft write" on public.inventory_count_items for insert to authenticated with check (exists(select 1 from public.inventory_counts c where c.id = inventory_count_id and c.created_by = auth.uid() and c.status = 'draft'));
create policy "count items own draft update" on public.inventory_count_items for update to authenticated using (exists(select 1 from public.inventory_counts c where c.id = inventory_count_id and c.created_by = auth.uid() and c.status = 'draft')) with check (exists(select 1 from public.inventory_counts c where c.id = inventory_count_id and c.created_by = auth.uid() and c.status = 'draft'));
-- Dobave vidi in ureja samo administrator.
create policy "deliveries admin manage" on public.deliveries for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "delivery items admin manage" on public.delivery_items for all to authenticated using (public.is_admin()) with check (public.is_admin());
