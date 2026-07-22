-- Precio distinto por tipo de vehículo (auto / camioneta).
-- Ejecutar UNA VEZ en Supabase → SQL Editor → Run.

alter table public.services
  add column if not exists price_camioneta numeric not null default 0;

-- Servicios existentes: si no tenían precio camioneta, copiar el de auto.
update public.services
set price_camioneta = price
where price_camioneta = 0 and price > 0;

comment on column public.services.price is 'Precio del servicio para auto.';
comment on column public.services.price_camioneta is 'Precio del servicio para camioneta.';
