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

-- ============================================================
-- 13. Счётчик запросов к ИИ (лимит в час на человека).
--     Доступ только у сервера (service role), политик нет.
-- ============================================================
create table if not exists public.ai_usage (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  kind       text not null check (kind in ('text', 'image')),
  created_at timestamptz not null default now()
);
create index if not exists ai_usage_user_time on public.ai_usage (user_id, kind, created_at desc);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from anon, authenticated;

-- 14. Password recovery (Edge Function `recover`; mail sent through Google Apps Script web app)
create table if not exists public.password_resets (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  code_hash text not null,
  expires_at timestamptz not null,
  attempts int not null default 0,
  used boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists password_resets_user_idx on public.password_resets(user_id, created_at desc);
alter table public.password_resets enable row level security;
-- server-only key/value (mail_url, mail_token); values are inserted manually, never committed
create table if not exists public.app_secrets (name text primary key, value text not null);
alter table public.app_secrets enable row level security;
revoke all on public.password_resets from anon, authenticated;
revoke all on public.app_secrets from anon, authenticated;

-- ============================================================
-- 15. Правка / удаление / скрытие сообщений (0.4.3)
-- Уже применено на проекте миграцией message_edit_delete_hide.
-- Здесь — только пометка; актуальное состояние смотри в миграциях Supabase.
-- ============================================================
-- messages.edited_at timestamptz; таблица message_hidden(message_id, user_id);
-- политики: отправитель может удалять свои сообщения и менять body/edited_at
-- (триггер запрещает менять их не отправителю); storage delete для своих файлов.

-- 16. (0.5.0) Альбомы и голосовые: сообщение kind='album' хранит вложения в messages.attachments
--     [{path,name,type(image|video|file|voice),mime,size}], лимит файла в chat-media 50 МБ.
-- alter table public.messages add column if not exists attachments jsonb;
-- alter table public.messages drop constraint if exists messages_kind_check;
-- alter table public.messages add constraint messages_kind_check check (kind = any (array['text','image','file','album']));
-- alter table public.messages drop constraint if exists messages_check1;
-- alter table public.messages add constraint messages_check1 check (body is not null or media_path is not null or attachments is not null);
-- alter table public.messages add constraint messages_attachments_check check (attachments is null or (jsonb_typeof(attachments) = 'array' and jsonb_array_length(attachments) between 1 and 20));
-- grant select (attachments), insert (attachments) on public.messages to authenticated;
-- update storage.buckets set file_size_limit = 52428800 where id = 'chat-media';

-- 17. Голосовые звонки (0.6.0): сигнальный канал WebRTC через опрос таблицы
-- call_signals(id, call_id uuid, sender, receiver, type [invite|accept|offer|answer|ice|end|decline], payload jsonb, created_at).
-- RLS: читать — отправитель/получатель; вставлять — только другу; удалять — обе стороны.
-- Триггер call_signals_purge_trg удаляет строки старше часа перед каждой вставкой.

-- 18. Группы, каналы, ответы, реакции, «печатает» (0.8): применено миграцией в проекте
-- chats(id, kind group|channel, title, description, avatar_url, owner, created_at), уникальный lower(title) для каналов;
-- chat_members(chat_id, user_id, role owner|admin|member, last_read bigint, joined_at); функции is_member/member_role/chat_kind/can_post;
-- messages: receiver nullable, chat_id uuid, reply_to bigint, CHECK (receiver is null) <> (chat_id is null); новые RLS по участникам;
-- message_reactions(message_id, user_id, emoji) — одна реакция на пользователя; profiles.typing_to/typing_at (+ grants на колонки).
