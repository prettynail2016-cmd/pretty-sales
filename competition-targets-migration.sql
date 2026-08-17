begin;

create table if not exists public.competitions (
  competition_id text primary key,
  display_name text not null,
  metric_type text not null default 'amount_quantity'
    check (metric_type in ('amount', 'quantity', 'amount_quantity', 'count', 'people')),
  active boolean not null default true,
  display_order integer not null default 100,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.competitions (competition_id, display_name, metric_type, active, display_order)
values
  ('package', '配套销售挑战', 'amount_quantity', true, 10),
  ('product', '产品销售挑战', 'amount_quantity', true, 20)
on conflict (competition_id) do nothing;

alter table public.sales_records
  add column if not exists competition_id text;

alter table public.sales_records
  drop constraint if exists sales_records_sale_type_check;

update public.sales_records
set competition_id = sale_type
where competition_id is null;

alter table public.targets
  add column if not exists competition_id text,
  add column if not exists target_month date;

alter table public.targets
  drop constraint if exists targets_sale_type_check;

update public.targets
set competition_id = sale_type
where competition_id is null;

update public.targets
set target_month = date_trunc('month', active_from)::date
where target_month is null;

create index if not exists sales_records_competition_id_idx
  on public.sales_records (competition_id);

create index if not exists targets_competition_month_idx
  on public.targets (competition_id, target_month);

alter table public.competitions enable row level security;

drop policy if exists "pretty sales competitions read" on public.competitions;
drop policy if exists "pretty sales competitions insert" on public.competitions;
drop policy if exists "pretty sales competitions update" on public.competitions;

create policy "pretty sales competitions read"
on public.competitions for select to anon, authenticated using (true);

create policy "pretty sales competitions insert"
on public.competitions for insert to anon, authenticated with check (active is true);

create policy "pretty sales competitions update"
on public.competitions for update to anon, authenticated using (true) with check (true);

grant select on public.competitions to anon, authenticated;
grant insert (competition_id, display_name, metric_type, active, display_order)
  on public.competitions to anon, authenticated;
grant update (display_name, metric_type, active, display_order, updated_at)
  on public.competitions to anon, authenticated;
revoke delete on public.competitions from anon, authenticated;

drop policy if exists "pretty sales targets insert" on public.targets;
drop policy if exists "pretty sales targets update" on public.targets;

create policy "pretty sales targets insert"
on public.targets for insert to anon, authenticated with check (true);

create policy "pretty sales targets update"
on public.targets for update to anon, authenticated using (true) with check (true);

grant select on public.targets to anon, authenticated;
grant insert (sale_type, competition_id, target_month, period_type, stage, target_amount, prizes, lucky_draw_ranks, qualification, active_from)
  on public.targets to anon, authenticated;
grant update (competition_id, target_month, target_amount, prizes, lucky_draw_ranks, qualification, active_from)
  on public.targets to anon, authenticated;
revoke delete on public.targets from anon, authenticated;

grant select, insert, update on public.sales_records to anon, authenticated;

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'competitions'
  ) then
    alter publication supabase_realtime add table public.competitions;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'targets'
  ) then
    alter publication supabase_realtime add table public.targets;
  end if;
end $$;

commit;
