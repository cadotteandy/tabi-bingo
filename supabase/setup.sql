-- Tabi Bingo: one-time Supabase setup.
-- Paste into Supabase > SQL Editor and run once.
-- Change the trip code on the last line to your own secret before running.
--
-- Security model: the tables have row level security on and no policies, so the
-- public key cannot touch them directly. Everything goes through the functions
-- below, and each one refuses to run without a valid trip code.

create table if not exists public.trips (
  code text primary key,
  created_at timestamptz not null default now()
);

create table if not exists public.config (
  trip text primary key references public.trips(code) on delete cascade,
  players jsonb not null,
  start_date date
);

create table if not exists public.marks (
  trip text not null references public.trips(code) on delete cascade,
  id text not null,
  date date not null,
  player text not null,
  idx int not null check (idx between 0 and 24),
  task text not null,
  note text not null default '',
  photo text,
  at bigint not null,
  updated_at timestamptz not null default now(),
  primary key (trip, id)
);

alter table public.trips  enable row level security;
alter table public.config enable row level security;
alter table public.marks  enable row level security;

create or replace function public.is_trip(p_code text)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.trips where code = p_code) $$;

create or replace function public.get_state(p_code text)
returns json language plpgsql stable security definer set search_path = ''
as $$
begin
  if not public.is_trip(p_code) then
    raise exception 'unknown trip code' using errcode = '28000';
  end if;
  return json_build_object(
    'config', (select row_to_json(c) from (
        select players, start_date from public.config where trip = p_code) c),
    'marks', coalesce((select json_agg(m) from (
        select id, date, player, idx, task, note, photo, at
        from public.marks where trip = p_code) m), '[]'::json)
  );
end $$;

create or replace function public.put_mark(
  p_code text, p_id text, p_date date, p_player text, p_idx int,
  p_task text, p_note text, p_photo text, p_at bigint)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_trip(p_code) then
    raise exception 'unknown trip code' using errcode = '28000';
  end if;
  if p_player not in ('p1', 'p2', 'p3') then
    raise exception 'unknown player';
  end if;
  insert into public.marks (trip, id, date, player, idx, task, note, photo, at)
  values (p_code, left(p_id, 64), p_date, p_player, p_idx, left(p_task, 200),
          left(coalesce(p_note, ''), 500), left(p_photo, 300), p_at)
  on conflict (trip, id) do update
    set note = excluded.note, photo = excluded.photo, task = excluded.task, updated_at = now();
end $$;

create or replace function public.delete_mark(p_code text, p_id text)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_trip(p_code) then
    raise exception 'unknown trip code' using errcode = '28000';
  end if;
  delete from public.marks where trip = p_code and id = p_id;
end $$;

create or replace function public.save_config(p_code text, p_players jsonb, p_start date)
returns void language plpgsql security definer set search_path = ''
as $$
begin
  if not public.is_trip(p_code) then
    raise exception 'unknown trip code' using errcode = '28000';
  end if;
  if jsonb_typeof(p_players) <> 'array' or jsonb_array_length(p_players) <> 3 then
    raise exception 'need exactly 3 players';
  end if;
  insert into public.config (trip, players, start_date) values (p_code, p_players, p_start)
  on conflict (trip) do update set players = excluded.players, start_date = excluded.start_date;
end $$;

revoke all on function public.is_trip(text) from public;
revoke all on function public.get_state(text) from public;
revoke all on function public.put_mark(text, text, date, text, int, text, text, text, bigint) from public;
revoke all on function public.delete_mark(text, text) from public;
revoke all on function public.save_config(text, jsonb, date) from public;
grant execute on function public.is_trip(text) to anon, authenticated;
grant execute on function public.get_state(text) to anon, authenticated;
grant execute on function public.put_mark(text, text, date, text, int, text, text, text, bigint) to anon, authenticated;
grant execute on function public.delete_mark(text, text) to anon, authenticated;
grant execute on function public.save_config(text, jsonb, date) to anon, authenticated;

-- Photo storage: anyone with a photo's link can view it (the link contains the
-- trip code). Uploads are only accepted into a folder named after a real trip code.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('proofs', 'proofs', true, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

drop policy if exists "Trip members upload proofs" on storage.objects;
create policy "Trip members upload proofs" on storage.objects
  for insert to anon, authenticated
  with check (bucket_id = 'proofs' and public.is_trip((storage.foldername(name))[1]));

-- Your secret trip code. Share it only with your group.
insert into public.trips (code) values ('CHANGE-ME-to-a-long-random-code')
on conflict do nothing;
