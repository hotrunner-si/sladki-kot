-- Zaposlenim z vlogo inventory omogoči samo branje podatkov za Pregled in Izdelke.
-- Zagon v Supabase SQL Editorju; ne podeli pravic urejanja ali brisanja.
create or replace function public.is_inventory() returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and role = 'inventory')
$$;

create policy "suppliers inventory read" on public.suppliers for select to authenticated using (public.is_admin() or public.is_inventory());
create policy "counts inventory completed read" on public.inventory_counts for select to authenticated using (public.is_admin() or public.is_inventory() or (created_by = auth.uid() and status = 'draft'));
create policy "count items inventory read" on public.inventory_count_items for select to authenticated using (public.is_admin() or public.is_inventory() or exists(select 1 from public.inventory_counts c where c.id = inventory_count_id and c.created_by = auth.uid()));
create policy "deliveries inventory read" on public.deliveries for select to authenticated using (public.is_admin() or public.is_inventory());
create policy "delivery items inventory read" on public.delivery_items for select to authenticated using (public.is_admin() or public.is_inventory());
