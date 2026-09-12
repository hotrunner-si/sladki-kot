-- ZA OBSTOJEČ PROJEKT: zaženite enkrat v Supabase SQL Editorju.
-- Obstoječe dobave obravnava kot že prejete, nove pa ostanejo naročene do potrditve.

alter table public.delivery_items
  add column if not exists received_at timestamptz;

alter table public.delivery_items
  alter column delivery_id drop not null;

update public.delivery_items di
set received_at = d.delivery_date::timestamp at time zone 'Europe/Ljubljana'
from public.deliveries d
where di.delivery_id = d.id
  and di.received_at is null;

create index if not exists delivery_items_received_idx
  on public.delivery_items(received_at desc)
  where received_at is not null;
