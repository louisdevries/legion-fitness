-- USDA FoodData Central as a third food source (generic, unbranded foods).
alter table public.foods drop constraint foods_source_check;
alter table public.foods
  add constraint foods_source_check check (source in ('off', 'user', 'usda'));

alter table public.foods
  add column fdc_id        bigint,
  -- Human label for serving_g, e.g. "1 egg, whole without shell".
  add column serving_label text;

-- One cached row per USDA food, shared by everyone.
create unique index foods_usda_fdc_id_key
  on public.foods (fdc_id) where source = 'usda';

-- Cached USDA rows are readable by everyone, like the OFF cache.
drop policy "foods_select" on public.foods;
create policy "foods_select" on public.foods
  for select to authenticated
  using (source in ('off', 'usda') or created_by = auth.uid());
