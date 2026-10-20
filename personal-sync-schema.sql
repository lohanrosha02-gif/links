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
