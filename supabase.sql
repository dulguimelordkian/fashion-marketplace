-- THREADLINE SUPABASE SCHEMA
create extension if not exists pgcrypto;

create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text,
 gcash_number text,
 created_at timestamptz not null default now()
);

create table if not exists public.products (
 id uuid primary key default gen_random_uuid(),
 seller_id uuid not null references public.profiles(id) on delete cascade,
 title text not null check (char_length(title) between 2 and 160),
 description text,
 category text,
 price numeric(12,2) not null check (price > 0),
 image_url text,
 is_active boolean not null default true,
 rating_avg numeric(3,2) not null default 0,
 review_count integer not null default 0,
 created_at timestamptz not null default now()
);

create table if not exists public.orders (
 id uuid primary key default gen_random_uuid(),
 buyer_id uuid not null references public.profiles(id),
 seller_id uuid not null references public.profiles(id),
 paymongo_checkout_session_id text unique,
 payment_id text unique,
 status text not null default 'pending' check (status in ('pending','paid','failed','cancelled','refunded')),
 total_amount numeric(12,2) not null check(total_amount>=0),
 created_at timestamptz not null default now(),
 paid_at timestamptz
);

create table if not exists public.order_items (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null references public.orders(id) on delete cascade,
 product_id uuid references public.products(id),
 quantity integer not null check(quantity>0),
 unit_price numeric(12,2) not null check(unit_price>=0),
 created_at timestamptz not null default now()
);

create table if not exists public.reviews (
 id uuid primary key default gen_random_uuid(),
 product_id uuid not null references public.products(id) on delete cascade,
 buyer_id uuid not null references public.profiles(id) on delete cascade,
 rating integer not null check(rating between 1 and 5),
 comment text check(char_length(comment)<=2000),
 created_at timestamptz not null default now(),
 unique(product_id,buyer_id)
);

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.reviews enable row level security;

create policy "profiles readable" on public.profiles for select using (true);
create policy "users update own profile" on public.profiles for update using (auth.uid()=id);
create policy "users insert own profile" on public.profiles for insert with check(auth.uid()=id);

create policy "products readable" on public.products for select using (is_active=true or seller_id=auth.uid());
create policy "users insert own products" on public.products for insert with check(auth.uid()=seller_id);
create policy "users update own products" on public.products for update using (auth.uid()=seller_id);
create policy "users delete own products" on public.products for delete using (auth.uid()=seller_id);

create policy "buyers read own orders" on public.orders for select using(auth.uid()=buyer_id);
create policy "sellers read own orders" on public.orders for select using(auth.uid()=seller_id);
create policy "users read relevant items" on public.order_items for select using(
 exists(select 1 from public.orders o where o.id=order_id and (o.buyer_id=auth.uid() or o.seller_id=auth.uid()))
);

create policy "reviews readable" on public.reviews for select using(true);
create policy "buyers create own reviews" on public.reviews for insert with check(auth.uid()=buyer_id);
create policy "buyers update own reviews" on public.reviews for update using(auth.uid()=buyer_id);

create or replace function public.update_product_rating()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 update products p set
  rating_avg=coalesce((select avg(r.rating)::numeric(3,2) from reviews r where r.product_id=coalesce(new.product_id,old.product_id)),0),
  review_count=(select count(*) from reviews r where r.product_id=coalesce(new.product_id,old.product_id))
 where p.id=coalesce(new.product_id,old.product_id);
 return null;
end $$;

create trigger reviews_rating_aiud after insert or update or delete on public.reviews
for each row execute function public.update_product_rating();

-- IMPORTANT: payment confirmation and order creation should be performed by a secure server-side
-- function using the Supabase service-role key, never by the browser.
