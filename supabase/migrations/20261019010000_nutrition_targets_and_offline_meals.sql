-- Daily nutrition targets, one row per user.
create table public.nutrition_targets (
  user_id    uuid primary key references auth.users (id) on delete cascade default auth.uid(),
  kcal       integer not null check (kcal > 0),
  protein_g  integer check (protein_g >= 0),
  carbs_g    integer check (carbs_g >= 0),
  fat_g      integer check (fat_g >= 0),
  updated_at timestamptz not null default now()
);

alter table public.nutrition_targets enable row level security;

create policy "nutrition_targets_own" on public.nutrition_targets
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


-- Offline support: the app generates each meal log's id on the device so
-- entries made offline can be synced (and re-synced) without duplicates.
alter table public.meal_logs
  add column client_id  uuid not null default gen_random_uuid(),
  add column updated_at timestamptz not null default now();

alter table public.meal_logs
  add constraint meal_logs_client_id_key unique (client_id);
