# Sladki kot · zaloga

Mobilno prilagojen MVP za lokal **Sladki kot na Veliki planini**. Temelji na načelu: **popisi + dobave → dejanska poraba → napoved → opozorilo za naročilo**. Trenutna zaloga ni shranjena kot spremenljivo polje, temveč se vedno izpelje iz zadnjega zaključenega popisa in zgodovine dobav.

## Lokalna namestitev

```bash
npm install
cp .env.example .env
npm run dev
```

V Windows PowerShell namesto `cp` uporabite:

```powershell
Copy-Item .env.example .env
```

V `.env` vstavite URL in anon ključ svojega Supabase projekta:

```text
VITE_SUPABASE_URL=https://vas-projekt.supabase.co
VITE_SUPABASE_ANON_KEY=vas_anon_public_key
```

Preverjanje produkcijskega paketa in forecast testov:

```bash
npm test
npm run build
```

## Supabase: nastavitev po korakih

1. Na [Supabase](https://supabase.com/dashboard) ustvarite nov projekt.
2. Odprite **SQL Editor** in v celoti izvedite [`supabase/schema.sql`](supabase/schema.sql).
3. V istem urejevalniku izvedite [`supabase/seed.sql`](supabase/seed.sql). Ta doda dobavitelje, 14 artiklov, šest zaključenih popisov in nekaj dobav.
4. V **Project Settings → API** kopirajte **Project URL** in **anon/public key** v `.env`, kot je prikazano zgoraj.
5. V **Authentication → Users → Add user** ustvarite prvega administratorja z e-pošto in geslom. Javne registracije aplikacija nima.
6. V podrobnostih pravkar ustvarjenega uporabnika kopirajte njegov UUID. V SQL Editorju nato izvedite (UUID in ime zamenjajte):

```sql
insert into public.profiles (id, full_name, role)
values ('UUID-ADMIN-UPORABNIKA', 'Janez Novak', 'admin');
```

7. Za zaposlenega ponovite ustvarjanje uporabnika v Authentication ter dodajte njegov profil:

```sql
insert into public.profiles (id, full_name, role)
values ('UUID-ZAPOSLENEGA', 'Miha Kovač', 'inventory');
```

8. Zaženite `npm run dev` in se prijavite.

### Posodobitev na aktualni seznam zaloge

Če ste že izvedli prvotni `schema.sql` in `seed.sql`, v SQL Editorju izvedite še [`supabase/migrate_current_inventory.sql`](supabase/migrate_current_inventory.sql). Skript doda nastavitve za štetje po platojih/paketih, nato izbriše začetne testne artikle, popise in dobave ter jih nadomesti z aktualnim seznamom in začetnim popisom. Profilov in Auth uporabnikov ne spreminja.

Če profil za prijavljenega uporabnika ni ustvarjen, aplikacija uporabnika obravnava kot omejenega uporabnika; profil vedno dodajte takoj po ustvarjanju Auth uporabnika.

## Vloge in varnost

RLS je vključen na vseh tabelah. Administrator lahko upravlja poslovne podatke, dobave, zgodovino popisov in profile. Uporabnik `inventory` vidi samo aktivne izdelke ter lahko ustvari in polni le svoj osnutek popisa; po zaključku ga ne more več brati ali spreminjati. Zaščita poti v odjemalcu je dodatna uporabniška zaščita, SQL politike pa dejanska zaščita podatkov.

Opomba za admina: trenutne Supabase RLS politike `profiles` preprečijo, da bi administrator sam ustvaril profil za novega uporabnika prek anonimnega ključa, saj uporabnik še ni prijavljen v aplikacijo. Profile ustvarite varno v SQL Editorju, kot v zgornjih primerih, ali pozneje dodajte ločen strežniški administrativni tok z `service_role` ključem (nikoli v odjemalsko aplikacijo).

## Podatkovni model in napoved

`schema.sql` določa tabele `profiles`, `suppliers`, `products`, `inventory_counts`, `inventory_count_items`, `deliveries` in `delivery_items`, indekse, omejitve, `updated_at` prožilce in RLS politike.

Napoved je v [`src/services/inventoryForecast.js`](src/services/inventoryForecast.js). Za artikel vzame največ pet zadnjih zaključenih popisov. Za vsak interval izračuna `prejšnja količina + dobave - naslednja količina`, negativno porabo izpusti, nato izračuna povprečje na dan. Brez primernega intervala pokaže »Ni dovolj podatkov«. Opozorilni prag je dobavni rok (prioriteta: izdelek, nato dobavitelj) + varnostna zaloga. Enostavni preveritveni primeri so v [`test/inventoryForecast.test.js`](test/inventoryForecast.test.js).

## Omejitve MVP-ja

Ni avtomatskega naročanja, e-poštnih ali push opozoril, POS/računov, črtnih kod in offline sinhronizacije. Ob neuspešnem shranjevanju aplikacija jasno sporoči napako in ne prikazuje lažnega uspeha. Struktura storitev in ločen forecast modul omogočata kasnejše razširitve, vključno s PWA/offline plastjo.
