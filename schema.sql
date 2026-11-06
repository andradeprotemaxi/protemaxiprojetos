-- =====================================================================
-- PROTEMAXI PROJETOS — banco de dados (Supabase)  ·  versão 2
-- Equipe com papéis, limite de acessos simultâneos, presença online,
-- chat da equipe e anotações.
-- Pode rodar de novo quantas vezes quiser: não apaga projetos nem fotos.
-- Supabase → SQL Editor → New query → cole tudo → Run
-- =====================================================================

-- ---------- Equipe e papéis ----------
create table if not exists public.equipe (
  email      text primary key,
  nome       text,
  admin      boolean not null default false,
  created_at timestamptz not null default now()
);
alter table public.equipe add column if not exists papel text not null default 'visitante';
alter table public.equipe drop constraint if exists equipe_papel_check;
alter table public.equipe add constraint equipe_papel_check check (papel in ('admin','editor','visitante'));
alter table public.equipe add column if not exists bloqueio_ate timestamptz;
update public.equipe set papel = 'admin' where admin = true and papel <> 'admin';
update public.equipe set email = lower(email) where email <> lower(email);

-- Ajustes gerais (limite de acessos simultâneos, contando o administrador)
create table if not exists public.ajustes (
  chave text primary key,
  valor integer not null
);
insert into public.ajustes (chave, valor) values ('limite_sessoes', 2) on conflict (chave) do nothing;

-- Sessões ativas (quem está dentro do app agora)
create table if not exists public.sessoes (
  email        text primary key,
  dispositivo  text not null,
  inicio       timestamptz not null default now(),
  ultimo_ping  timestamptz not null default now()
);

-- ---------- Funções de permissão ----------
create or replace function public.meu_email() returns text
language sql stable as $$ select lower(coalesce(auth.jwt() ->> 'email', '')) $$;

create or replace function public.meu_papel() returns text
language sql stable security definer set search_path = public as $$
  select papel from public.equipe where email = public.meu_email();
$$;
create or replace function public.is_membro() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.equipe where email = public.meu_email());
$$;
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.meu_papel() = 'admin', false);
$$;
create or replace function public.is_editor() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.meu_papel() in ('admin','editor'), false);
$$;
create or replace function public.sessao_ativa() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.sessoes where email = public.meu_email() and ultimo_ping > now() - interval '2 minutes');
$$;
-- Só entra quem é da equipe E está com sessão ativa (o administrador sempre entra)
create or replace function public.pode_acessar() returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_membro() and (public.is_admin() or public.sessao_ativa());
$$;

-- ---------- Controle de vagas ----------
create or replace function public.online_agora() returns json
language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(email), '[]'::json) from public.sessoes where ultimo_ping > now() - interval '90 seconds';
$$;

create or replace function public.entrar_sessao(p_dispositivo text) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_email text := public.meu_email();
  v_papel text;
  v_limite int;
  v_ocupadas int;
  v_quem text;
begin
  select papel into v_papel from public.equipe where email = v_email;
  if v_papel is null then
    return json_build_object('ok', false, 'motivo', 'sem_acesso');
  end if;
  delete from public.sessoes where ultimo_ping < now() - interval '90 seconds';
  if v_papel <> 'admin' and exists (select 1 from public.equipe where email = v_email and bloqueio_ate > now()) then
    return json_build_object('ok', false, 'motivo', 'derrubado');
  end if;
  if v_papel <> 'admin' then
    select valor into v_limite from public.ajustes where chave = 'limite_sessoes';
    v_limite := coalesce(v_limite, 2);
    -- uma vaga é sempre do administrador; o restante é disputado
    select count(*), string_agg(coalesce(e.nome, s.email), ', ')
      into v_ocupadas, v_quem
      from public.sessoes s
      left join public.equipe e on e.email = s.email
     where coalesce(e.papel, 'visitante') <> 'admin' and s.email <> v_email;
    if v_ocupadas >= greatest(v_limite - 1, 0) then
      return json_build_object('ok', false, 'motivo', 'lotado', 'quem', v_quem);
    end if;
  end if;
  insert into public.sessoes (email, dispositivo, inicio, ultimo_ping)
  values (v_email, p_dispositivo, now(), now())
  on conflict (email) do update set dispositivo = excluded.dispositivo, inicio = now(), ultimo_ping = now();
  return json_build_object('ok', true, 'papel', v_papel, 'limite', coalesce(v_limite, 2), 'online', public.online_agora());
end $$;

create or replace function public.ping_sessao(p_dispositivo text) returns json
language plpgsql security definer set search_path = public as $$
begin
  update public.sessoes set ultimo_ping = now() where email = public.meu_email() and dispositivo = p_dispositivo;
  if not found then
    return json_build_object('ok', false, 'motivo', 'encerrada', 'online', public.online_agora());
  end if;
  return json_build_object('ok', true, 'online', public.online_agora());
end $$;

create or replace function public.sair_sessao(p_dispositivo text) returns void
language sql security definer set search_path = public as $$
  delete from public.sessoes where email = public.meu_email() and dispositivo = p_dispositivo;
$$;

create or replace function public.derrubar_sessao(p_email text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Apenas o administrador pode encerrar sessões'; end if;
  delete from public.sessoes where email = lower(p_email);
  update public.equipe set bloqueio_ate = now() + interval '5 minutes' where email = lower(p_email) and papel <> 'admin';
end $$;

revoke all on function public.entrar_sessao(text)   from anon;
revoke all on function public.ping_sessao(text)     from anon;
revoke all on function public.sair_sessao(text)     from anon;
revoke all on function public.derrubar_sessao(text) from anon;
revoke all on function public.online_agora()        from anon;

-- ---------- Projetos e configurações ----------
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

create table if not exists public.configuracoes (
  id          text primary key default 'empresa',
  dados       jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now()
);

-- ---------- Chat e anotações ----------
create table if not exists public.mensagens (
  id           bigint generated always as identity primary key,
  email        text not null default public.meu_email(),
  nome         text,
  texto        text not null check (char_length(texto) between 1 and 2000),
  projeto_id   uuid,
  projeto_nome text,
  created_at   timestamptz not null default now()
);
create index if not exists mensagens_data_idx on public.mensagens(created_at desc);

create table if not exists public.notas (
  id           bigint generated always as identity primary key,
  email        text not null default public.meu_email(),
  nome         text,
  titulo       text not null check (char_length(titulo) between 1 and 120),
  texto        text not null default '' check (char_length(texto) <= 4000),
  projeto_id   uuid,
  projeto_nome text,
  fixada       boolean not null default false,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------- Regras de acesso (RLS) ----------
alter table public.equipe        enable row level security;
alter table public.ajustes       enable row level security;
alter table public.sessoes       enable row level security;
alter table public.projetos      enable row level security;
alter table public.configuracoes enable row level security;
alter table public.mensagens     enable row level security;
alter table public.notas         enable row level security;

do $$ declare r record; begin
  for r in select policyname, tablename from pg_policies where schemaname = 'public'
    and tablename in ('equipe','ajustes','sessoes','projetos','configuracoes','mensagens','notas') loop
    execute format('drop policy if exists %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

create policy "equipe_ler"     on public.equipe for select to authenticated using (public.is_membro());
create policy "equipe_inserir" on public.equipe for insert to authenticated with check (public.is_admin());
create policy "equipe_alterar" on public.equipe for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "equipe_apagar"  on public.equipe for delete to authenticated using (public.is_admin() and email <> public.meu_email());

create policy "ajustes_ler"     on public.ajustes for select to authenticated using (public.is_membro());
create policy "ajustes_alterar" on public.ajustes for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "sessoes_ler" on public.sessoes for select to authenticated using (public.is_membro());

create policy "projetos_ler"     on public.projetos for select to authenticated using (public.pode_acessar());
create policy "projetos_inserir" on public.projetos for insert to authenticated with check (public.pode_acessar() and public.is_editor());
create policy "projetos_alterar" on public.projetos for update to authenticated using (public.pode_acessar() and public.is_editor()) with check (public.pode_acessar() and public.is_editor());
create policy "projetos_apagar"  on public.projetos for delete to authenticated using (public.pode_acessar() and public.is_editor());

create policy "config_ler"     on public.configuracoes for select to authenticated using (public.pode_acessar());
create policy "config_inserir" on public.configuracoes for insert to authenticated with check (public.is_admin());
create policy "config_alterar" on public.configuracoes for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy "msg_ler"     on public.mensagens for select to authenticated using (public.pode_acessar());
create policy "msg_inserir" on public.mensagens for insert to authenticated with check (public.pode_acessar() and email = public.meu_email());
create policy "msg_apagar"  on public.mensagens for delete to authenticated using (public.pode_acessar() and (email = public.meu_email() or public.is_admin()));

create policy "notas_ler"     on public.notas for select to authenticated using (public.pode_acessar());
create policy "notas_inserir" on public.notas for insert to authenticated with check (public.pode_acessar() and email = public.meu_email());
create policy "notas_alterar" on public.notas for update to authenticated using (public.pode_acessar() and (email = public.meu_email() or public.is_admin())) with check (public.pode_acessar());
create policy "notas_apagar"  on public.notas for delete to authenticated using (public.pode_acessar() and (email = public.meu_email() or public.is_admin()));

-- ---------- Arquivos (fotos, plantas, logos) ----------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('projetos', 'projetos', false, 15728640, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;

drop policy if exists "arquivos_equipe_ler"     on storage.objects;
drop policy if exists "arquivos_equipe_enviar"  on storage.objects;
drop policy if exists "arquivos_equipe_alterar" on storage.objects;
drop policy if exists "arquivos_equipe_apagar"  on storage.objects;
create policy "arquivos_equipe_ler"     on storage.objects for select to authenticated using (bucket_id = 'projetos' and public.pode_acessar());
create policy "arquivos_equipe_enviar"  on storage.objects for insert to authenticated with check (bucket_id = 'projetos' and public.pode_acessar() and public.is_editor());
create policy "arquivos_equipe_alterar" on storage.objects for update to authenticated using (bucket_id = 'projetos' and public.pode_acessar() and public.is_editor());
create policy "arquivos_equipe_apagar"  on storage.objects for delete to authenticated using (bucket_id = 'projetos' and public.pode_acessar() and public.is_editor());

-- ---------- Tempo real (chat e presença) ----------
do $$ begin
  begin alter publication supabase_realtime add table public.mensagens; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.notas;     exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.sessoes;   exception when duplicate_object then null; end;
end $$;

-- ---------- Administrador ----------
-- >>> Se o seu e-mail for outro, troque aqui <<<
insert into public.equipe (email, nome, admin, papel) values ('andrade@protemaxi.com.br', 'Andrade', true, 'admin')
on conflict (email) do update set admin = true, papel = 'admin', nome = coalesce(public.equipe.nome, 'Andrade');
