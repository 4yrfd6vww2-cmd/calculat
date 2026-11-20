-- neirox: схема базы данных (Supabase / Postgres)
-- Запускается один раз в Supabase: SQL Editor -> New query -> вставить -> Run.

-- ============================================================
-- 1. Профили (публичная часть: ник, аватар, был в сети)
-- ============================================================
create table if not exists public.profiles (
  id          uuid primary key references auth.users (id) on delete cascade,
  nick        text not null unique
              check (nick ~ '^[a-z0-9_]{3,20}$'),
  avatar_url  text,
  last_seen   timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

-- ============================================================
-- 2. Почта для восстановления пароля (видна только владельцу).
--    Привязывается один раз: изменить и удалить нельзя.
-- ============================================================
create table if not exists public.private_profiles (
  user_id         uuid primary key references auth.users (id) on delete cascade,
  recovery_email  text not null unique
                  check (recovery_email = lower(recovery_email)
                         and recovery_email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  created_at      timestamptz not null default now()
);

-- ============================================================
-- 3. Друзья: заявка (pending), друзья (accepted), блокировка (blocked)
--    Для blocked: requester - кто заблокировал, addressee - кого.
-- ============================================================
create table if not exists public.friendships (
  id          bigint generated always as identity primary key,
  requester   uuid not null references public.profiles (id) on delete cascade,
  addressee   uuid not null references public.profiles (id) on delete cascade,
  status      text not null default 'pending'
              check (status in ('pending', 'accepted', 'blocked')),
  created_at  timestamptz not null default now(),
  check (requester <> addressee)
);

-- одна пара людей - одна запись, в любом направлении
create unique index if not exists friendships_pair_uniq
  on public.friendships (least(requester, addressee), greatest(requester, addressee));
create index if not exists friendships_addressee_idx on public.friendships (addressee);

-- ============================================================
-- 4. Сообщения (только между друзьями)
-- ============================================================
create table if not exists public.messages (
  id          bigint generated always as identity primary key,
  sender      uuid not null references public.profiles (id) on delete cascade,
  receiver    uuid not null references public.profiles (id) on delete cascade,
  kind        text not null default 'text'
              check (kind in ('text', 'image', 'file')),
  body        text check (char_length(body) <= 4000),
  media_path  text,
  file_name   text,
  created_at  timestamptz not null default now(),
  read_at     timestamptz,
  check (sender <> receiver),
  check (body is not null or media_path is not null)
);

create index if not exists messages_receiver_idx on public.messages (receiver, created_at desc);
create index if not exists messages_pair_idx
  on public.messages (least(sender, receiver), greatest(sender, receiver), created_at desc);

-- ============================================================
-- 5. Автоматически создаём профиль при регистрации
--    (ник приложение передаёт в metadata: nick)
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, nick)
  values (new.id, lower(new.raw_user_meta_data ->> 'nick'));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================
-- 6. Проверка "мы друзья?"
-- ============================================================
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.requester = a and f.addressee = b)
        or (f.requester = b and f.addressee = a))
  );
$$;

-- ============================================================
-- 7. Заблокировать человека (заменяет любую прежнюю связь)
-- ============================================================
create or replace function public.block_user(target uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if target = auth.uid() then
    raise exception 'cannot block yourself';
  end if;
  delete from public.friendships
  where (requester = auth.uid() and addressee = target)
     or (requester = target and addressee = auth.uid());
  insert into public.friendships (requester, addressee, status)
  values (auth.uid(), target, 'blocked');
end;
$$;

-- ============================================================
-- 8. Безопасность (RLS): кто что видит и меняет
-- ============================================================
alter table public.profiles         enable row level security;
alter table public.private_profiles enable row level security;
alter table public.friendships      enable row level security;
alter table public.messages         enable row level security;

-- profiles: ник и аватар видят все вошедшие, менять можно только свой
drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles
  for select to authenticated using (true);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles
  for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- private_profiles: только владелец; добавить можно один раз, менять нельзя
drop policy if exists private_select_own on public.private_profiles;
create policy private_select_own on public.private_profiles
  for select to authenticated using (user_id = auth.uid());

drop policy if exists private_insert_own on public.private_profiles;
create policy private_insert_own on public.private_profiles
  for insert to authenticated with check (user_id = auth.uid());

-- friendships
drop policy if exists friendships_select on public.friendships;
create policy friendships_select on public.friendships
  for select to authenticated
  using (auth.uid() in (requester, addressee));

drop policy if exists friendships_insert on public.friendships;
create policy friendships_insert on public.friendships
  for insert to authenticated
  with check (requester = auth.uid() and status = 'pending');

drop policy if exists friendships_accept on public.friendships;
create policy friendships_accept on public.friendships
  for update to authenticated
  using (addressee = auth.uid() and status = 'pending')
  with check (addressee = auth.uid() and status = 'accepted');

-- отозвать заявку, отклонить, удалить из друзей (заблокированного удалить нельзя)
drop policy if exists friendships_delete on public.friendships;
create policy friendships_delete on public.friendships
  for delete to authenticated
  using (auth.uid() in (requester, addressee) and status <> 'blocked');

-- messages
drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages
  for select to authenticated
  using (auth.uid() in (sender, receiver));

drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages
  for insert to authenticated
  with check (sender = auth.uid() and public.are_friends(sender, receiver));

drop policy if exists messages_mark_read on public.messages;
create policy messages_mark_read on public.messages
  for update to authenticated
  using (receiver = auth.uid()) with check (receiver = auth.uid());

-- ============================================================
-- 9. Права доступа для приложения (только вошедшие пользователи)
-- ============================================================
grant usage on schema public to authenticated;

grant select on public.profiles to authenticated;
grant update (avatar_url, last_seen) on public.profiles to authenticated;

grant select, insert on public.private_profiles to authenticated;

grant select, insert, delete on public.friendships to authenticated;
grant update (status) on public.friendships to authenticated;

grant select, insert on public.messages to authenticated;
grant update (read_at) on public.messages to authenticated;

grant execute on function public.block_user(uuid) to authenticated;
revoke execute on function public.are_friends(uuid, uuid) from public, anon;
grant execute on function public.are_friends(uuid, uuid) to authenticated;

-- ============================================================
-- 10. Мгновенная доставка (Realtime)
-- ============================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'messages'
  ) then
    alter publication supabase_realtime add table public.messages;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'friendships'
  ) then
    alter publication supabase_realtime add table public.friendships;
  end if;
end;
$$;

-- ============================================================
-- 11. Хранилище файлов: аватарки (публичные) и вложения чатов
-- ============================================================
insert into storage.buckets (id, name, public, file_size_limit)
values ('avatars', 'avatars', true, 5242880)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-media', 'chat-media', false, 26214400)
on conflict (id) do nothing;

-- файлы лежат в папке с id владельца: <user_id>/имя_файла
drop policy if exists avatars_write_own on storage.objects;
create policy avatars_write_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists avatars_update_own on storage.objects;
create policy avatars_update_own on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists chatmedia_write_own on storage.objects;
create policy chatmedia_write_own on storage.objects
  for insert to authenticated
  with check (bucket_id = 'chat-media' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists chatmedia_read on storage.objects;
create policy chatmedia_read on storage.objects
  for select to authenticated
  using (bucket_id = 'chat-media');

-- ============================================================
-- 12. Закрываем лишний доступ к служебным функциям
-- ============================================================
revoke execute on function public.block_user(uuid) from public, anon;
grant execute on function public.block_user(uuid) to authenticated;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
