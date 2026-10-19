-- Foods: a shared cache of Open Food Facts products plus each user's own
-- custom foods. Nutrition is stored per 100 g so every source is comparable.
create table public.foods (
  id            bigint generated always as identity primary key,
  source        text not null check (source in ('off', 'user')),
  barcode       text,
  name          text not null,
  brand         text,
  kcal_100g     numeric not null check (kcal_100g >= 0),
  protein_100g  numeric,
  carbs_100g    numeric,
  fat_100g      numeric,
  fiber_100g    numeric,
  sugar_100g    numeric,
  salt_100g     numeric,
  serving_g     numeric check (serving_g > 0),
  image_url     text,
  created_by    uuid references auth.users (id) on delete cascade default auth.uid(),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- One cached Open Food Facts row per barcode, shared by everyone.
create unique index foods_off_barcode_key
  on public.foods (barcode) where source = 'off';

-- A user's own entry for a barcode (e.g. one OFF doesn't have).
create unique index foods_user_barcode_key
  on public.foods (created_by, barcode) where source = 'user' and barcode is not null;

create index foods_name_search_idx
  on public.foods using gin (to_tsvector('simple', name || ' ' || coalesce(brand, '')));

alter table public.foods enable row level security;

-- Everyone can read the OFF cache; custom foods are private to their creator.
create policy "foods_select" on public.foods
  for select to authenticated
  using (source = 'off' or created_by = auth.uid());

create policy "foods_insert" on public.foods
  for insert to authenticated
  with check (created_by = auth.uid());

-- Only custom foods are editable, and only by their creator. Cached OFF
-- rows stay as fetched.
create policy "foods_update" on public.foods
  for update to authenticated
  using (source = 'user' and created_by = auth.uid())
  with check (source = 'user' and created_by = auth.uid());

create policy "foods_delete" on public.foods
  for delete to authenticated
  using (source = 'user' and created_by = auth.uid());


-- Meal logs: what a user ate, as a food + amount in grams.
create table public.meal_logs (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users (id) on delete cascade default auth.uid(),
  food_id    bigint not null references public.foods (id) on delete restrict,
  meal_type  text not null check (meal_type in ('breakfast', 'lunch', 'dinner', 'snack')),
  grams      numeric not null check (grams > 0),
  logged_at  timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index meal_logs_user_day_idx on public.meal_logs (user_id, logged_at);

alter table public.meal_logs enable row level security;

create policy "meal_logs_own" on public.meal_logs
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
