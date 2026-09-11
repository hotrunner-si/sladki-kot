-- Nastavi začetne/originalne količine kot NOV zaključen popis.
-- Ne briše izdelkov, dobav ali zgodovine. Zaženite v Supabase SQL Editorju.
begin;

create temporary table original_stock (
  name text primary key,
  quantity numeric(12,3) not null check (quantity >= 0)
) on commit drop;

insert into original_stock (name, quantity) values
('Limonin sirup',6),('Bezgov sirup',0),('Bubble tea',0),('Veronika',23),
('Coca-Cola Zero',37),('Coca-Cola',70),('Fanta',45),('Domač jogurt',12),
('Kislo mleko',2),('Romerquelle',0),('Hrenovke',16),('Klobasa s sirom',6),
('Klobasa, kranjska',4),('Kakav',0),('Kava',0),('Krompir',4),
('Čebulni obročki',0),('Piščančji trakci',10),('La Popsi malina',22),
('La Popsi jagoda',0),('La Popsi pomaranča',0),('La Popsi ananas',0),
('La Popsi pasijonka',0),('La Popsi mango',0),('Čaj Kaja',18),('Kombuča',0),
('Magnetki',6),('Obeski',21),('Pivo Mali grad',0),('Špricar',20),
('Meninc, gozdni mož',42),('Meninc, malina',7),('Meninc, smrekovi vršički',0),
('Meninc, svetlo',20),('Meninc, temno',41),('Meninc, pšenično',0),('Mleko',13),
('Voda Sladki kot',30),('Radler Isotonik',17),('Union',97),('Laško',36),
('Hotdog štručke',19),('Štruklji',15),('Borovničke',3),('Jägermeister',0.5),
('Medica',1),('Višnjevec',1),('Sadjevec',2),('Pelinkovec',1.5),('Čaj',3),
('Trnič',4),('Silver tejp',1),('Vrečke, prozorne',1),('Folija, alu',3),
('Rola listkov za blagajno',1),('Brisačke',3),('Ladjice',4),('Slamce',2),
('Vilce',22),('Noži',40),('Žlice',1),('Žličke za sladoled',0),
('Šalčke za omakce',0),('Prtički',0),('Nabodala',5),('Kozarci, pivo 0,5',7),
('Kozarci, sok 0,2',3),('Kozarci, kava 0,2',75),('Kozarci, espresso',45),
('Kozarci, shot',80),('Palčke za kavo',1000),('Šalčke za sladoled',100),
('Pražena čebula',2),('Sladkor',2),('Sol',1),('Masa za sladoled',6),
('Masa za palačinke',6),('Smetana',4),('Poliv jagoda',4),('Poliv karamela',5),
('Poliv pistacija',6),('Poliv čokolada',2),('Omakca, bela',1),('Omakca BBQ',0),
('Posip, penice',0),('Posip, mrvice',0),('Posip, kokos',0),('Posip, lešniki',0),
('Posip, arašidi',0),('Olje za friteze',3),('Voda, balon',5),
('Vreče za smeti zunaj',1),('Vreče za smeti notri',3);

-- Ne dovoli delnega popisa, če je kateri artikel izbrisan ali preimenovan.
do $$
declare missing_names text;
begin
  select string_agg(s.name, ', ' order by s.name) into missing_names
  from original_stock s left join public.products p on p.name = s.name
  where p.id is null;
  if missing_names is not null then
    raise exception 'Manjkajo izdelki v katalogu: %', missing_names;
  end if;
end $$;

with new_count as (
  insert into public.inventory_counts (status, started_at, completed_at, notes)
  values ('completed', now(), now(), 'Ponastavitev na originalno začetno stanje')
  returning id
)
insert into public.inventory_count_items (inventory_count_id, product_id, quantity)
select new_count.id, p.id, s.quantity
from new_count
cross join original_stock s
join public.products p on p.name = s.name;

commit;
