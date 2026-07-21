-- GOATcars CRM (lavadero) — esquema Supabase
-- Ejecutá esto en: Supabase Dashboard → SQL → New query → Run
--
-- Después: Authentication → Users → Add user (email/contraseña).
-- Realtime: Database → Publications → supabase_realtime
-- y agregá: sales, cash_movements, services, crm_settings, pending_receivables,
-- invoices, pipeline_leads, salespeople, cash_week_closes.

-- ── Servicios (catálogo del lavadero) ──────────────────────────────────────
create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  price numeric not null default 0 check (price >= 0),
  cost numeric not null default 0 check (cost >= 0),
  active boolean not null default true,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists services_user_name on public.services (user_id, lower(name));
create index if not exists services_user_active on public.services (user_id, active);

alter table public.services enable row level security;

drop policy if exists "services_select_own" on public.services;
drop policy if exists "services_insert_own" on public.services;
drop policy if exists "services_update_own" on public.services;
drop policy if exists "services_delete_own" on public.services;

create policy "services_select_own" on public.services for select using (auth.uid() = user_id);
create policy "services_insert_own" on public.services for insert with check (auth.uid() = user_id);
create policy "services_update_own" on public.services for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "services_delete_own" on public.services for delete using (auth.uid() = user_id);

-- ── Ventas (una fila por línea de servicio) ────────────────────────────────
create table if not exists public.sales (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  sale_date date not null,
  client_name text not null,
  phone text default '',
  ig_handle text not null default '',
  -- Servicio
  service_name text not null,
  quantity int not null check (quantity > 0),
  unit_sale numeric not null check (unit_sale >= 0),
  unit_cost numeric not null check (unit_cost >= 0),
  -- Vehículo
  vehicle_plate text not null default '',
  vehicle_brand text not null default '',
  vehicle_model text not null default '',
  vehicle_type text not null default '',
  -- Pago
  payment text default '',
  payment_cash numeric not null default 0 check (payment_cash >= 0),
  payment_transfer numeric not null default 0 check (payment_transfer >= 0),
  payment_card numeric not null default 0 check (payment_card >= 0),
  payment_other numeric not null default 0 check (payment_other >= 0),
  sale_total numeric not null,
  cost_total numeric not null,
  profit numeric not null,
  -- Vendedor / comisión
  seller_id uuid,
  commission_pct_applied numeric,
  commission_amount numeric not null default 0 check (commission_amount >= 0),
  commission_paid boolean not null default false,
  commission_paid_at timestamptz,
  -- Seguimiento del auto en el lavadero
  status text not null default 'en_proceso' check (status in ('en_proceso', 'terminado', 'entregado')),
  order_id uuid,
  finished_at timestamptz,
  created_at timestamptz default now()
);

create index if not exists sales_user_date on public.sales (user_id, sale_date desc);
create index if not exists sales_user_plate on public.sales (user_id, vehicle_plate);
create index if not exists sales_user_status on public.sales (user_id, status);
create index if not exists sales_user_order on public.sales (user_id, order_id);

alter table public.sales enable row level security;

drop policy if exists "sales_select_own" on public.sales;
drop policy if exists "sales_insert_own" on public.sales;
drop policy if exists "sales_update_own" on public.sales;
drop policy if exists "sales_delete_own" on public.sales;

create policy "sales_select_own" on public.sales for select using (auth.uid() = user_id);
create policy "sales_insert_own" on public.sales for insert with check (auth.uid() = user_id);
create policy "sales_update_own" on public.sales for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "sales_delete_own" on public.sales for delete using (auth.uid() = user_id);

-- ── Caja ───────────────────────────────────────────────────────────────────
create table if not exists public.cash_movements (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  movement_type text not null check (movement_type in ('ingreso', 'egreso')),
  movement_date date not null,
  concept text not null,
  amount numeric not null check (amount >= 0),
  egreso_kind text check (egreso_kind is null or egreso_kind in ('operativo', 'restock', 'tecnico')),
  reparto_dest text,
  created_at timestamptz default now()
);

create index if not exists cash_user_date on public.cash_movements (user_id, movement_date desc);

alter table public.cash_movements enable row level security;

drop policy if exists "cash_select_own" on public.cash_movements;
drop policy if exists "cash_insert_own" on public.cash_movements;
drop policy if exists "cash_update_own" on public.cash_movements;
drop policy if exists "cash_delete_own" on public.cash_movements;

create policy "cash_select_own" on public.cash_movements for select using (auth.uid() = user_id);
create policy "cash_insert_own" on public.cash_movements for insert with check (auth.uid() = user_id);
create policy "cash_update_own" on public.cash_movements for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "cash_delete_own" on public.cash_movements for delete using (auth.uid() = user_id);

-- ── Ajustes CRM ────────────────────────────────────────────────────────────
create table if not exists public.crm_settings (
  user_id uuid primary key references auth.users (id) on delete cascade,
  dolar_blue_ars_per_usd numeric not null default 0 check (dolar_blue_ars_per_usd >= 0),
  updated_at timestamptz not null default now()
);

alter table public.crm_settings enable row level security;

drop policy if exists "crm_settings_select_own" on public.crm_settings;
drop policy if exists "crm_settings_insert_own" on public.crm_settings;
drop policy if exists "crm_settings_update_own" on public.crm_settings;

create policy "crm_settings_select_own" on public.crm_settings for select using (auth.uid() = user_id);
create policy "crm_settings_insert_own" on public.crm_settings for insert with check (auth.uid() = user_id);
create policy "crm_settings_update_own" on public.crm_settings for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Deudores / cobros pendientes ───────────────────────────────────────────
create table if not exists public.pending_receivables (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  client_name text not null,
  concept text not null default '',
  amount_pending numeric not null check (amount_pending >= 0),
  due_date date,
  kind text not null default 'cuotas' check (kind in ('cuotas', 'tarjeta', 'otro')),
  notes text default '',
  created_at timestamptz default now()
);

create index if not exists recv_user_due on public.pending_receivables (user_id, due_date);

alter table public.pending_receivables enable row level security;

drop policy if exists "recv_select_own" on public.pending_receivables;
drop policy if exists "recv_insert_own" on public.pending_receivables;
drop policy if exists "recv_update_own" on public.pending_receivables;
drop policy if exists "recv_delete_own" on public.pending_receivables;

create policy "recv_select_own" on public.pending_receivables for select using (auth.uid() = user_id);
create policy "recv_insert_own" on public.pending_receivables for insert with check (auth.uid() = user_id);
create policy "recv_update_own" on public.pending_receivables for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "recv_delete_own" on public.pending_receivables for delete using (auth.uid() = user_id);

-- ── Pipeline ───────────────────────────────────────────────────────────────
do $$ begin
  create type public.pipeline_stage as enum (
    'nuevo',
    'contactado',
    'interesado',
    'cita',
    'venta',
    'perdido'
  );
exception
  when duplicate_object then null;
end $$;

create table if not exists public.pipeline_leads (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  stage public.pipeline_stage not null default 'nuevo'::public.pipeline_stage,
  source text not null default 'manual',
  manychat_subscriber_id text not null default '',
  phone text not null default '',
  name text not null default '',
  email text not null default '',
  ig_handle text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  last_manychat_interaction_at timestamptz,
  assigned_to text not null default '',
  converted_sale_id uuid references public.sales (id) on delete set null,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists pipeline_leads_user_stage on public.pipeline_leads (user_id, stage);
create index if not exists pipeline_leads_user_created on public.pipeline_leads (user_id, created_at desc);
create index if not exists pipeline_leads_user_phone_norm on public.pipeline_leads (user_id, phone);

create unique index if not exists pipeline_leads_user_manychat_unique
  on public.pipeline_leads (user_id, manychat_subscriber_id)
  where manychat_subscriber_id is not null and manychat_subscriber_id <> '';

alter table public.pipeline_leads enable row level security;

drop policy if exists "pipeline_leads_select_own" on public.pipeline_leads;
drop policy if exists "pipeline_leads_insert_own" on public.pipeline_leads;
drop policy if exists "pipeline_leads_update_own" on public.pipeline_leads;
drop policy if exists "pipeline_leads_delete_own" on public.pipeline_leads;

create policy "pipeline_leads_select_own" on public.pipeline_leads for select using (auth.uid() = user_id);
create policy "pipeline_leads_insert_own" on public.pipeline_leads for insert with check (auth.uid() = user_id);
create policy "pipeline_leads_update_own" on public.pipeline_leads for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "pipeline_leads_delete_own" on public.pipeline_leads for delete using (auth.uid() = user_id);

-- ── Facturación ────────────────────────────────────────────────────────────
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  sale_id uuid not null references public.sales (id) on delete cascade,
  sale_date date,
  client_name text not null default '',
  invoice_number text not null,
  invoice_type text not null check (invoice_type in ('ticket', 'factura_a', 'factura_b', 'nota_credito')),
  issue_date date not null,
  subtotal numeric not null check (subtotal >= 0),
  tax_pct numeric not null default 0 check (tax_pct >= 0 and tax_pct <= 100),
  tax_amount numeric not null default 0 check (tax_amount >= 0),
  total numeric not null check (total >= 0),
  notes text not null default '',
  status text not null default 'emitido' check (status in ('emitido', 'anulado')),
  created_at timestamptz not null default now()
);

create unique index if not exists invoices_user_number_unique on public.invoices (user_id, invoice_number);
create index if not exists invoices_user_issue_date on public.invoices (user_id, issue_date desc);
create index if not exists invoices_user_sale on public.invoices (user_id, sale_id);

alter table public.invoices enable row level security;

drop policy if exists "invoices_select_own" on public.invoices;
drop policy if exists "invoices_insert_own" on public.invoices;
drop policy if exists "invoices_update_own" on public.invoices;
drop policy if exists "invoices_delete_own" on public.invoices;

create policy "invoices_select_own" on public.invoices for select using (auth.uid() = user_id);
create policy "invoices_insert_own" on public.invoices for insert with check (auth.uid() = user_id);
create policy "invoices_update_own" on public.invoices for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "invoices_delete_own" on public.invoices for delete using (auth.uid() = user_id);

-- ── Vendedores / operarios ─────────────────────────────────────────────────
create table if not exists public.salespeople (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  commission_pct numeric not null default 0 check (commission_pct >= 0 and commission_pct <= 100),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create index if not exists salespeople_user_name on public.salespeople (user_id, lower(name));

alter table public.sales
  drop constraint if exists sales_seller_id_fkey;
alter table public.sales
  add constraint sales_seller_id_fkey
  foreign key (seller_id) references public.salespeople (id) on delete set null;

create index if not exists sales_user_seller on public.sales (user_id, seller_id);

alter table public.salespeople enable row level security;

drop policy if exists "salespeople_select_own" on public.salespeople;
drop policy if exists "salespeople_insert_own" on public.salespeople;
drop policy if exists "salespeople_update_own" on public.salespeople;
drop policy if exists "salespeople_delete_own" on public.salespeople;

create policy "salespeople_select_own" on public.salespeople for select using (auth.uid() = user_id);
create policy "salespeople_insert_own" on public.salespeople for insert with check (auth.uid() = user_id);
create policy "salespeople_update_own" on public.salespeople for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "salespeople_delete_own" on public.salespeople for delete using (auth.uid() = user_id);

-- ── Cierres semanales de caja ───────────────────────────────────────────────
create table if not exists public.cash_week_closes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  week_start date not null,
  week_end date not null,
  close_date date not null,
  expected_cash numeric not null default 0,
  expected_transfer numeric not null default 0,
  expected_card numeric not null default 0,
  expected_other numeric not null default 0,
  expected_total numeric not null default 0,
  counted_cash numeric not null default 0,
  counted_transfer numeric not null default 0,
  counted_card numeric not null default 0,
  counted_other numeric not null default 0,
  counted_total numeric not null default 0,
  notes text not null default '',
  created_at timestamptz not null default now()
);

create unique index if not exists cash_week_closes_user_week
  on public.cash_week_closes (user_id, week_start);

alter table public.cash_week_closes enable row level security;

drop policy if exists "week_closes_select_own" on public.cash_week_closes;
drop policy if exists "week_closes_insert_own" on public.cash_week_closes;
drop policy if exists "week_closes_update_own" on public.cash_week_closes;
drop policy if exists "week_closes_delete_own" on public.cash_week_closes;

create policy "week_closes_select_own" on public.cash_week_closes for select using (auth.uid() = user_id);
create policy "week_closes_insert_own" on public.cash_week_closes for insert with check (auth.uid() = user_id);
create policy "week_closes_update_own" on public.cash_week_closes for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "week_closes_delete_own" on public.cash_week_closes for delete using (auth.uid() = user_id);

comment on table public.services is 'Catálogo de servicios del lavadero (lavado, detailing, etc.).';
comment on table public.sales is 'Ventas: una fila por servicio del carrito; incluye datos del vehículo.';
comment on column public.cash_movements.reparto_dest is 'Destino del movimiento: reparto|reserva|restock(insumos)|socios|tecnico.';
