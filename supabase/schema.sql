-- =====================================================================
-- PROTEMAXI PROJETOS — banco de dados (Supabase)
-- Cole tudo no Supabase → SQL Editor → New query → Run
-- ANTES DE RODAR: troque o e-mail na ÚLTIMA LINHA pelo e-mail do administrador.
-- =====================================================================

-- Equipe liberada: só quem está aqui vê e edita os projetos
create table if not exists public.equipe (
  email      text primary key,
  nome       text,
  admin      boolean not null default false,
  created_at timestamptz not null default now()
);

create or replace function public.is_membro() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.equipe where lower(email) = lower(auth.jwt() ->> 'email'));
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.equipe where lower(email) = lower(auth.jwt() ->> 'email') and admin);
$$;
revoke all on function public.is_membro() from anon;
revoke all on function public.is_admin()  from anon;

-- Projetos (compartilhados pela equipe)
create table if not exists public.projetos (
  id          uuid primary key,
  criado_por  uuid default auth.uid() references auth.users(id) on delete set null,
  nome        text not null,
  cliente     text,
  status      text not null default 'novo' check (status in ('novo','execucao','concluido')),
  dados       jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists projetos_upd_idx on public.projetos(updated_at desc);

-- Configurações da empresa (perfil, catálogo Inside, textos, parâmetros)
create table if not exists public.configuracoes (
  id          text primary key default 'empresa',
  dados       jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

alter table public.equipe        enable row level security;
alter table public.projetos      enable row level security;
alter table public.configuracoes enable row level security;

drop policy if exists "equipe_ler"     on public.equipe;
drop policy if exists "equipe_admin"   on public.equipe;
drop policy if exists "projetos_equipe" on public.projetos;
drop policy if exists "config_equipe"  on public.configuracoes;

create policy "equipe_ler"   on public.equipe for select to authenticated using (public.is_membro());
create policy "equipe_admin" on public.equipe for all    to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "projetos_equipe" on public.projetos for all to authenticated using (public.is_membro()) with check (public.is_membro());
create policy "config_equipe"   on public.configuracoes for all to authenticated using (public.is_membro()) with check (public.is_membro());

-- Arquivos (fotos, plantas, logos) em bucket privado
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('projetos', 'projetos', false, 15728640, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "arquivos_equipe_ler"     on storage.objects;
drop policy if exists "arquivos_equipe_enviar"  on storage.objects;
drop policy if exists "arquivos_equipe_alterar" on storage.objects;
drop policy if exists "arquivos_equipe_apagar"  on storage.objects;
create policy "arquivos_equipe_ler"     on storage.objects for select to authenticated using (bucket_id = 'projetos' and public.is_membro());
create policy "arquivos_equipe_enviar"  on storage.objects for insert to authenticated with check (bucket_id = 'projetos' and public.is_membro());
create policy "arquivos_equipe_alterar" on storage.objects for update to authenticated using (bucket_id = 'projetos' and public.is_membro());
create policy "arquivos_equipe_apagar"  on storage.objects for delete to authenticated using (bucket_id = 'projetos' and public.is_membro());

-- >>> TROQUE PELO SEU E-MAIL (administrador) <<<
insert into public.equipe (email, nome, admin) values ('andrade@protemaxi.com.br', 'Andrade', true)
on conflict (email) do update set admin = true;
