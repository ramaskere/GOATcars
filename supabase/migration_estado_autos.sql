-- Seguimiento de autos en el lavadero: estado por orden de trabajo.
-- Ejecutar UNA VEZ en Supabase → SQL Editor → Run.
--
-- status:      en_proceso → terminado → entregado
-- order_id:    agrupa las líneas de servicio del mismo auto (mismo ingreso)
-- finished_at: cuándo se terminó el lavado

alter table public.sales add column if not exists status text;

-- Las ventas ya cargadas se consideran cerradas para no llenar la cola de autos.
update public.sales set status = 'entregado' where status is null;

alter table public.sales alter column status set default 'en_proceso';
alter table public.sales alter column status set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'sales_status_check'
  ) then
    alter table public.sales
      add constraint sales_status_check check (status in ('en_proceso', 'terminado', 'entregado'));
  end if;
end $$;

alter table public.sales add column if not exists order_id uuid;
alter table public.sales add column if not exists finished_at timestamptz;

create index if not exists sales_user_status on public.sales (user_id, status);
create index if not exists sales_user_order on public.sales (user_id, order_id);

comment on column public.sales.status is 'Estado del auto: en_proceso | terminado | entregado.';
comment on column public.sales.order_id is 'Agrupa líneas de servicio del mismo ingreso (mismo auto).';
