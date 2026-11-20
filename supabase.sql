-- Winter Arc – Cloud-Sicherung
-- Einmal im Supabase-Dashboard unter „SQL Editor“ einfügen und auf „Run“ klicken.
-- Auf dem Server liegt nur verschlüsselter Text. Lesen kann ihn nur, wer den Wiederherstellungs-Code hat.

create table if not exists public.wa_vault (
  id         text primary key check (length(id) = 64),
  data       text not null check (length(data) < 8000000),
  rev        bigint not null default 1,
  updated_at timestamptz not null default now()
);

-- Niemand darf direkt auf die Tabelle zugreifen – nur über die zwei Funktionen unten.
alter table public.wa_vault enable row level security;
revoke all on public.wa_vault from anon, authenticated;

create or replace function public.wa_get(p_id text)
returns table(data text, rev bigint)
language sql security definer set search_path = ''
as $$
  select v.data, v.rev from public.wa_vault v where v.id = p_id;
$$;

-- Schreibt nur, wenn der Stand, auf dem das Handy aufbaut (p_base), noch aktuell ist.
-- Sonst kommt null zurück und die App holt erst den neuen Stand.
create or replace function public.wa_put(p_id text, p_data text, p_base bigint)
returns bigint
language plpgsql security definer set search_path = ''
as $$
declare r bigint;
begin
  if length(p_id) <> 64 then raise exception 'invalid id'; end if;
  if p_base = 0 then
    insert into public.wa_vault(id, data, rev) values (p_id, p_data, 1)
    on conflict (id) do nothing
    returning rev into r;
  else
    update public.wa_vault set data = p_data, rev = rev + 1, updated_at = now()
    where id = p_id and rev = p_base
    returning rev into r;
  end if;
  return r;
end;
$$;

revoke all on function public.wa_get(text) from public;
revoke all on function public.wa_put(text, text, bigint) from public;
grant execute on function public.wa_get(text) to anon;
grant execute on function public.wa_put(text, text, bigint) to anon;
