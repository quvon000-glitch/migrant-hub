-- Uzbek banks often refuse foreign servers: when the official CBU rate is missing or stale,
-- the snapshot uses so'm rates calculated from the Bank of Russia cross rate (basis = 'cross').
create or replace function public.fx_snapshot() returns jsonb
language sql stable security definer set search_path = '' as $$
  with latest as (
    select source, max(rate_date) d from public.fx_rates group by source
  ), main as (
    select case
      when (select d from latest where source = 'cbu') is not null
       and (select d from latest where source = 'cbu') >= coalesce((select d from latest where source = 'cross'), '-infinity'::date) - 3 then 'cbu'
      when (select d from latest where source = 'cross') is not null then 'cross'
    end as src
  ), cur as (
    select f.* from public.fx_rates f join latest l on l.source = f.source and l.d = f.rate_date
  )
  select case when (select src from main) is null then null else jsonb_build_object(
    'basis', (select src from main),
    'date', (select d from latest where source = (select src from main)),
    'rates', (select jsonb_object_agg(ccy, jsonb_build_object('rate', rate, 'diff', diff)) from cur where source = (select src from main)),
    'fetched_at', (select max(fetched_at) from cur where source = (select src from main)),
    'rub_history', (select jsonb_agg(jsonb_build_object('date', rate_date, 'rate', rate) order by rate_date)
                    from (select rate_date, rate from public.fx_rates where source = (select src from main) and ccy = 'RUB' order by rate_date desc limit 8) h),
    'cbr', (select jsonb_build_object('date', (select d from latest where source = 'cbr'),
              'rates', jsonb_object_agg(ccy, jsonb_build_object('rate', rate, 'diff', diff))) from cur where source = 'cbr'),
    'nbu', (select jsonb_build_object('date', (select d from latest where source = 'nbu_cash'),
              'cash', (select jsonb_object_agg(ccy, jsonb_build_object('buy', rate, 'sell', sell)) from cur where source = 'nbu_cash'),
              'app', (select jsonb_object_agg(ccy, jsonb_build_object('buy', rate, 'sell', sell)) from cur where source = 'nbu_app')))
  ) end;
$$;
