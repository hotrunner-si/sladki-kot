-- ZA OBSTOJEČ PROJEKT: zaženite enkrat v Supabase SQL Editorju.
-- Varnostno zalogo spremeni iz števila dni v količino izdelka.
alter table public.products add column if not exists safety_stock_quantity numeric(12,3) not null default 0 check (safety_stock_quantity >= 0);
update public.products set safety_stock_quantity = coalesce(safety_stock_days, 0) where safety_stock_quantity = 0;
