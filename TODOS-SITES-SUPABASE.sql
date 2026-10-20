-- CONFIGURAÇÃO ÚNICA | Sincronização privada do Meu Bolso, Meu Estudo, Rifa Isaac, Meus Links
-- Compatível com o banco Supabase da LOBI, desde que você seja o administrador dele.
-- Segurança: tabelas pessoais exigem login e Row Level Security.
-- Rode em SQL Editor do projeto Supabase antes de colocar chaves públicas nos sites.

-- Meu Bolso: dados privados sincronizados por usuário.
-- Execute no SQL Editor do SEU projeto Supabase.
-- Nunca use a chave service_role no navegador ou no repositório.

create table if not exists public.meu_bolso_cloud (
  user_id uuid primary key references auth.users(id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  version bigint not null default 1 check (version > 0),
  updated_at timestamptz not null default now(),
  constraint meu_bolso_payload_object check (jsonb_typeof(payload) = 'object')
);

alter table public.meu_bolso_cloud enable row level security;
revoke all on public.meu_bolso_cloud from anon;
grant select, insert, update on public.meu_bolso_cloud to authenticated;

drop policy if exists meu_bolso_owner_read on public.meu_bolso_cloud;
drop policy if exists meu_bolso_owner_insert on public.meu_bolso_cloud;
drop policy if exists meu_bolso_owner_update on public.meu_bolso_cloud;

create policy meu_bolso_owner_read on public.meu_bolso_cloud
 for select to authenticated
 using ((select auth.uid()) = user_id);

create policy meu_bolso_owner_insert on public.meu_bolso_cloud
 for insert to authenticated
 with check ((select auth.uid()) = user_id);

create policy meu_bolso_owner_update on public.meu_bolso_cloud
 for update to authenticated
 using ((select auth.uid()) = user_id)
 with check ((select auth.uid()) = user_id);

-- Write atomically with an expected version.
-- Prevents a stale browser from silently overwriting another device.
create or replace function public.meu_bolso_write(
  p_expected_version bigint,
  p_payload jsonb
)
returns table (written boolean, server_version bigint)
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
  v_user uuid := (select auth.uid());
  v_version bigint;
begin
  if v_user is null then
    raise exception 'Autenticação necessária' using errcode = '28000';
  end if;
  if p_expected_version is null or p_expected_version < 0 then
    raise exception 'Versão inválida';
  end if;
  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Dados inválidos';
  end if;
  if p_expected_version = 0 then
    insert into public.meu_bolso_cloud(user_id,payload,version,updated_at)
    values (v_user,p_payload,1,now())
    on conflict (user_id) do nothing
    returning version into v_version;
  else
    update public.meu_bolso_cloud
    set payload = p_payload, version = version + 1, updated_at = now()
    where user_id = v_user and version = p_expected_version
    returning version into v_version;
  end if;
  return query select (v_version is not null), coalesce(v_version,0)::bigint;
end;
$fn$;

revoke all on function public.meu_bolso_write(bigint,jsonb) from public, anon;
grant execute on function public.meu_bolso_write(bigint,jsonb) to authenticated;

-- The frontend only uses the public/publishable key. Authorization
-- is enforced by Supabase Auth and PostgreSQL Row Level Security.

-- Habilite notificações Postgres Changes para a mesma tabela.
-- As políticas RLS limitam eventos à linha do usuário autenticado.
do $sync$
begin
  if not exists(select 1 from pg_catalog.pg_publication where pubname='supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists(
    select 1 from pg_catalog.pg_publication_tables
    where pubname='supabase_realtime'
      and schemaname='public' and tablename='meu_bolso_cloud'
  ) then
    alter publication supabase_realtime add table public.meu_bolso_cloud;
  end if;
end
$sync$;


-- Sincronização privada para Meu Estudo, Rifa Isaac e Meus Links
-- Executar UMA VEZ em um projeto Supabase administrado pelo proprietário.
-- Sem segredos em sites públicos. Requer Auth por e-mail e chave publishable.

create table if not exists public.personal_site_snapshots(
  user_id uuid not null references auth.users(id) on delete cascade,
  app text not null check (app in ('meu-estudo','rifa-isaac','meus-links')),
  payload jsonb not null default '{}'::jsonb check(jsonb_typeof(payload)='object'),
  version bigint not null default 1 check(version>0),
  updated_at timestamptz not null default now(),
  primary key(user_id,app)
);
alter table public.personal_site_snapshots enable row level security;
revoke all on public.personal_site_snapshots from anon;
grant select, insert, update on public.personal_site_snapshots to authenticated;

drop policy if exists "personal_owner_select" on public.personal_site_snapshots;
drop policy if exists "personal_owner_insert" on public.personal_site_snapshots;
drop policy if exists "personal_owner_update" on public.personal_site_snapshots;

create policy "personal_owner_select" on public.personal_site_snapshots
 for select to authenticated using ((select auth.uid())=user_id);
create policy "personal_owner_insert" on public.personal_site_snapshots
 for insert to authenticated with check ((select auth.uid())=user_id);
create policy "personal_owner_update" on public.personal_site_snapshots
 for update to authenticated using ((select auth.uid())=user_id)
 with check ((select auth.uid())=user_id);

create or replace function public.personal_site_write(
  p_app text,
  p_expected_version bigint,
  p_payload jsonb
)
returns table(written boolean,server_version bigint)
language plpgsql security invoker set search_path=''
as $func$
declare v_user uuid := (select auth.uid());v_version bigint;
begin
  if v_user is null then raise exception 'Autenticacao necessaria' using errcode='28000';end if;
  if p_app not in ('meu-estudo','rifa-isaac','meus-links') then
    raise exception 'Aplicacao desconhecida';
  end if;
  if p_expected_version is null or p_expected_version<0 or p_payload is null
    or jsonb_typeof(p_payload)<>'object' then raise exception 'Dados invalidos';end if;
  if p_expected_version=0 then
    insert into public.personal_site_snapshots(user_id,app,payload,version,updated_at)
      values(v_user,p_app,p_payload,1,now())
    on conflict (user_id,app) do nothing returning version into v_version;
  else
    update public.personal_site_snapshots
    set payload=p_payload,version=version+1,updated_at=now()
    where user_id=v_user and app=p_app and version=p_expected_version
    returning version into v_version;
  end if;
  return query select (v_version is not null),coalesce(v_version,0)::bigint;
end;
$func$;
revoke all on function public.personal_site_write(text,bigint,jsonb) from public,anon;
grant execute on function public.personal_site_write(text,bigint,jsonb) to authenticated;

-- Realtime: eventos autenticados continuam submetidos às regras RLS.
do $sync$
begin
  if not exists(select 1 from pg_catalog.pg_publication where pubname='supabase_realtime') then
    create publication supabase_realtime;
  end if;
  if not exists(select 1 from pg_catalog.pg_publication_tables
    where pubname='supabase_realtime' and schemaname='public'
    and tablename='personal_site_snapshots') then
    alter publication supabase_realtime add table public.personal_site_snapshots;
  end if;
end
$sync$;


-- Notificações ao vivo da LOBI, apenas se a tabela products existir no mesmo projeto.
-- Essa etapa NÃO cria a loja nem modifica as políticas RLS da tabela de produtos.
do $lobi_realtime$
begin
  if to_regclass('public.products') is not null then
    if not exists(
      select 1 from pg_catalog.pg_publication_tables
      where pubname='supabase_realtime' and schemaname='public'
        and tablename='products'
    ) then
      alter publication supabase_realtime add table public.products;
    end if;
  end if;
end
$lobi_realtime$;
