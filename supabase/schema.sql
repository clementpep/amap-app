-- ============================================================
-- AMAP App — Supabase / PostgreSQL Schema
-- Run this in Supabase SQL Editor
-- ============================================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- ============================================================
-- PROFILES — extends auth.users
-- ============================================================
create table if not exists public.profiles (
  id          uuid references auth.users on delete cascade primary key,
  full_name   text not null,
  amap_name   text not null default 'Mon AMAP',
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Profiles are viewable by authenticated members"
  on public.profiles for select
  using (auth.role() = 'authenticated');

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, amap_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    coalesce(new.raw_user_meta_data->>'amap_name', 'Mon AMAP')
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- PRODUCTS — catalogue produits (local + Open Food Facts)
-- ============================================================
create table if not exists public.products (
  id            uuid default uuid_generate_v4() primary key,
  name          text not null,
  category      text,
  unit          text default 'kg',   -- kg, g, L, pièce, botte
  barcode       text unique,
  image_url     text,
  off_id        text unique,         -- Open Food Facts product id
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index if not exists products_name_idx on public.products using gin(to_tsvector('french', name));
create index if not exists products_barcode_idx on public.products(barcode);

alter table public.products enable row level security;

create policy "Products readable by authenticated users"
  on public.products for select
  using (auth.role() = 'authenticated');

create policy "Authenticated users can insert products"
  on public.products for insert
  with check (auth.role() = 'authenticated');

create policy "Authenticated users can update products"
  on public.products for update
  using (auth.role() = 'authenticated');

-- ============================================================
-- PRICE_REFERENCES — prix bio/conventionnel par produit
-- ============================================================
create table if not exists public.price_references (
  id            uuid default uuid_generate_v4() primary key,
  product_id    uuid references public.products on delete cascade not null,
  price_type    text not null check (price_type in ('bio', 'conv')),
  price         numeric(10, 2) not null,
  unit          text not null default 'kg',
  source        text not null default 'manual' check (source in ('manual', 'open_prices', 'open_food_facts')),
  location      text,               -- store name or location
  recorded_at   timestamptz not null default now(),
  created_by    uuid references auth.users on delete set null,
  created_at    timestamptz not null default now()
);

create index if not exists price_refs_product_idx on public.price_references(product_id, price_type, recorded_at desc);

alter table public.price_references enable row level security;

create policy "Prices readable by authenticated users"
  on public.price_references for select
  using (auth.role() = 'authenticated');

create policy "Authenticated users can insert prices"
  on public.price_references for insert
  with check (auth.role() = 'authenticated');

-- ============================================================
-- VIEW: latest_prices — dernier prix valide par produit/type
-- ============================================================
create or replace view public.latest_prices as
select distinct on (product_id, price_type)
  id,
  product_id,
  price_type,
  price,
  unit,
  source,
  location,
  recorded_at
from public.price_references
order by product_id, price_type, recorded_at desc;

-- ============================================================
-- DELIVERIES — un panier par semaine par utilisateur
-- ============================================================
create table if not exists public.deliveries (
  id                  uuid default uuid_generate_v4() primary key,
  user_id             uuid references auth.users on delete cascade not null,
  delivered_at        date not null default current_date,
  photo_url           text,
  notes               text,
  total_bio_price     numeric(10, 2),
  total_conv_price    numeric(10, 2),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists deliveries_user_date_idx on public.deliveries(user_id, delivered_at desc);

alter table public.deliveries enable row level security;

create policy "Users can see own deliveries"
  on public.deliveries for select
  using (auth.uid() = user_id);

create policy "Users can insert own deliveries"
  on public.deliveries for insert
  with check (auth.uid() = user_id);

create policy "Users can update own deliveries"
  on public.deliveries for update
  using (auth.uid() = user_id);

create policy "Users can delete own deliveries"
  on public.deliveries for delete
  using (auth.uid() = user_id);

-- ============================================================
-- BASKET_ITEMS — produits d'une livraison
-- ============================================================
create table if not exists public.basket_items (
  id            uuid default uuid_generate_v4() primary key,
  delivery_id   uuid references public.deliveries on delete cascade not null,
  product_id    uuid references public.products on delete set null,
  product_name  text not null,       -- denormalized for display even if product deleted
  quantity      numeric(10, 3) not null default 1,
  unit          text not null default 'kg',
  is_bio        boolean not null default true,
  unit_price    numeric(10, 2),      -- prix payé
  created_at    timestamptz not null default now()
);

create index if not exists basket_items_delivery_idx on public.basket_items(delivery_id);

alter table public.basket_items enable row level security;

create policy "Users can see items of own deliveries"
  on public.basket_items for select
  using (
    exists (
      select 1 from public.deliveries d
      where d.id = delivery_id and d.user_id = auth.uid()
    )
  );

create policy "Users can insert items for own deliveries"
  on public.basket_items for insert
  with check (
    exists (
      select 1 from public.deliveries d
      where d.id = delivery_id and d.user_id = auth.uid()
    )
  );

create policy "Users can update items of own deliveries"
  on public.basket_items for update
  using (
    exists (
      select 1 from public.deliveries d
      where d.id = delivery_id and d.user_id = auth.uid()
    )
  );

create policy "Users can delete items of own deliveries"
  on public.basket_items for delete
  using (
    exists (
      select 1 from public.deliveries d
      where d.id = delivery_id and d.user_id = auth.uid()
    )
  );

-- ============================================================
-- MATERIALIZED VIEW: monthly_stats
-- ============================================================
create materialized view if not exists public.monthly_stats as
select
  d.user_id,
  date_trunc('month', d.delivered_at) as month,
  count(d.id) as delivery_count,
  avg(d.total_bio_price) as avg_bio_price,
  avg(d.total_conv_price) as avg_conv_price,
  sum(d.total_bio_price) as total_bio_spent,
  sum(d.total_conv_price) as total_conv_reference,
  sum(d.total_conv_price - d.total_bio_price) as total_savings
from public.deliveries d
where d.total_bio_price is not null
  and d.total_conv_price is not null
group by d.user_id, date_trunc('month', d.delivered_at)
order by d.user_id, month desc;

create unique index if not exists monthly_stats_unique_idx
  on public.monthly_stats(user_id, month);

-- Refresh function (call via cron or after new delivery)
create or replace function public.refresh_monthly_stats()
returns void
language sql
security definer
as $$
  refresh materialized view concurrently public.monthly_stats;
$$;

-- ============================================================
-- STORAGE: delivery-photos bucket
-- (Run in Supabase Dashboard > Storage or via API)
-- ============================================================
-- insert into storage.buckets (id, name, public)
-- values ('delivery-photos', 'delivery-photos', false);

-- create policy "Users can upload own photos"
--   on storage.objects for insert
--   with check (
--     bucket_id = 'delivery-photos' and
--     auth.uid()::text = (storage.foldername(name))[1]
--   );

-- create policy "Users can view own photos"
--   on storage.objects for select
--   using (
--     bucket_id = 'delivery-photos' and
--     auth.uid()::text = (storage.foldername(name))[1]
--   );

-- ============================================================
-- UPDATED_AT trigger helper
-- ============================================================
create or replace function public.update_updated_at_column()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.update_updated_at_column();

create trigger deliveries_updated_at
  before update on public.deliveries
  for each row execute procedure public.update_updated_at_column();

create trigger products_updated_at
  before update on public.products
  for each row execute procedure public.update_updated_at_column();
