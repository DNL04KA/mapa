-- Схема базы MAPA.
--
-- Пишется до подключения сервера намеренно: поменять структуру таблиц, когда
-- в них уже лежат чужие маршруты и отзывы, стоит на порядок дороже, чем
-- подумать сейчас. Весь файл выполняется в редакторе Supabase одним куском.
--
-- Главное правило: запрет по умолчанию. Row Level Security включён на каждой
-- таблице, и доступ открывается по одному правилу за раз. Обратный порядок —
-- «сначала работает, потом закроем» — заканчивается тем, что чужие черновики
-- читает кто угодно.

-- ───────────────────────── Профили ─────────────────────────

create table public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  -- Короткое имя для ссылки на профиль. Меняется редко, видно всем.
  handle      text unique not null check (handle ~ '^[a-z0-9_]{3,20}$'),
  name        text not null check (length(name) between 1 and 50),
  avatar_path text,
  bio         text check (bio is null or length(bio) <= 200),
  created_at  timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Профиль видят все: на него ходят смотреть маршруты.
create policy "профили читают все"
  on public.profiles for select using (true);

create policy "свой профиль правит владелец"
  on public.profiles for update using (auth.uid() = id);

create policy "профиль создаёт сам пользователь"
  on public.profiles for insert with check (auth.uid() = id);

-- ───────────────────────── Маршруты ─────────────────────────

create table public.routes (
  id           uuid primary key default gen_random_uuid(),
  author_id    uuid not null references public.profiles on delete cascade,
  title        text not null check (length(title) between 1 and 80),
  country_id   text,
  -- Черновик виден только автору. Публикация — отдельное решение,
  -- а не побочный эффект сохранения.
  is_published boolean not null default false,
  published_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index routes_author_idx    on public.routes (author_id);
create index routes_published_idx on public.routes (is_published, published_at desc);
create index routes_country_idx   on public.routes (country_id) where is_published;

alter table public.routes enable row level security;

create policy "опубликованные маршруты читают все"
  on public.routes for select
  using (is_published or auth.uid() = author_id);

create policy "маршрут создаёт автор"
  on public.routes for insert with check (auth.uid() = author_id);

create policy "маршрут правит автор"
  on public.routes for update using (auth.uid() = author_id);

create policy "маршрут удаляет автор"
  on public.routes for delete using (auth.uid() = author_id);

-- ──────────────────────── Точки маршрута ────────────────────────

create table public.route_points (
  id           uuid primary key default gen_random_uuid(),
  route_id     uuid not null references public.routes on delete cascade,
  -- Порядок хранится числом, а не порядком строк: в SQL у строк
  -- порядка нет, а маршрут — это именно последовательность.
  position     int  not null,
  city_id      text,
  name         text not null,
  country_name text,
  lon          double precision not null,
  lat          double precision not null,
  days         int  not null default 2 check (days between 1 and 60),
  budget       int  not null default 0 check (budget >= 0),
  note         text check (note is null or length(note) <= 500),
  photo_path   text,
  unique (route_id, position)
);

create index route_points_route_idx on public.route_points (route_id, position);

alter table public.route_points enable row level security;

-- Точки наследуют право доступа у маршрута: отдельного «опубликован»
-- у них нет, и дублировать его значило бы однажды разойтись.
create policy "точки видны вместе с маршрутом"
  on public.route_points for select
  using (exists (
    select 1 from public.routes r
    where r.id = route_id and (r.is_published or r.author_id = auth.uid())
  ));

create policy "точки правит автор маршрута"
  on public.route_points for all
  using (exists (
    select 1 from public.routes r where r.id = route_id and r.author_id = auth.uid()
  ))
  with check (exists (
    select 1 from public.routes r where r.id = route_id and r.author_id = auth.uid()
  ));

-- ───────────────────────── Отзывы ─────────────────────────

create table public.route_reviews (
  id         uuid primary key default gen_random_uuid(),
  route_id   uuid not null references public.routes on delete cascade,
  author_id  uuid not null references public.profiles on delete cascade,
  rating     int  not null check (rating between 1 and 5),
  text       text check (text is null or length(text) <= 1000),
  created_at timestamptz not null default now(),
  -- Один отзыв на человека: иначе оценку накручивают в одиночку.
  unique (route_id, author_id)
);

create index route_reviews_route_idx on public.route_reviews (route_id);

alter table public.route_reviews enable row level security;

create policy "отзывы читают все"
  on public.route_reviews for select using (true);

-- Своё хвалить нельзя. Это не морализаторство: без запрета верх рейтинга
-- за неделю займут авторы, поставившие себе пятёрки.
create policy "отзыв пишет не автор маршрута"
  on public.route_reviews for insert
  with check (
    auth.uid() = author_id
    and not exists (
      select 1 from public.routes r where r.id = route_id and r.author_id = auth.uid()
    )
  );

create policy "свой отзыв правит автор отзыва"
  on public.route_reviews for update using (auth.uid() = author_id);

create policy "свой отзыв удаляет автор отзыва"
  on public.route_reviews for delete using (auth.uid() = author_id);

-- ──────────────────── Сохранения и подписки ────────────────────

create table public.route_saves (
  route_id   uuid not null references public.routes on delete cascade,
  user_id    uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (route_id, user_id)
);

alter table public.route_saves enable row level security;

create policy "сохранения видит владелец"
  on public.route_saves for select using (auth.uid() = user_id);

create policy "сохраняет и убирает сам пользователь"
  on public.route_saves for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table public.follows (
  follower_id uuid not null references public.profiles on delete cascade,
  followee_id uuid not null references public.profiles on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);

alter table public.follows enable row level security;

create policy "подписки читают все"
  on public.follows for select using (true);

create policy "подписывается сам пользователь"
  on public.follows for all
  using (auth.uid() = follower_id) with check (auth.uid() = follower_id);

-- ───────────────────── Жалобы и блокировки ─────────────────────
--
-- Не «на будущее». Приложение с чужим содержимым без возможности
-- пожаловаться и заблокировать не проходит проверку App Store —
-- правило 1.2. Поэтому таблицы заводятся вместе с самим содержимым,
-- а не когда-нибудь потом.

create table public.blocks (
  blocker_id uuid not null references public.profiles on delete cascade,
  blocked_id uuid not null references public.profiles on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

alter table public.blocks enable row level security;

create policy "блокировки видит тот, кто блокировал"
  on public.blocks for select using (auth.uid() = blocker_id);

create policy "блокирует сам пользователь"
  on public.blocks for all
  using (auth.uid() = blocker_id) with check (auth.uid() = blocker_id);

create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.profiles on delete cascade,
  target_type text not null check (target_type in ('route', 'review', 'profile')),
  target_id   uuid not null,
  reason      text not null check (length(reason) between 1 and 500),
  created_at  timestamptz not null default now()
);

alter table public.reports enable row level security;

create policy "жалобу пишет сам пользователь"
  on public.reports for insert with check (auth.uid() = reporter_id);

create policy "свои жалобы видит отправитель"
  on public.reports for select using (auth.uid() = reporter_id);

-- ─────────────────── Популярные маршруты ───────────────────
--
-- Средняя оценка сама по себе ранжирует плохо: маршрут с одной пятёркой
-- обходит маршрут с сотней четвёрок. Поэтому сглаживаем к средней по всей
-- базе тем сильнее, чем меньше отзывов — это обычный байесовский рейтинг.
-- Пять в знаменателе означает «пока отзывов меньше пяти, доверяем больше
-- общей средней, чем этому маршруту».

create view public.popular_routes as
with overall as (
  select coalesce(avg(rating), 4.0) as mean from public.route_reviews
)
select
  r.id,
  r.author_id,
  -- Никнейм и имя автора прямо здесь: иначе, чтобы подписать строку в
  -- топе, телефону пришлось бы делать второй запрос на каждый маршрут.
  a.handle                                                 as author_handle,
  a.name                                                   as author_name,
  r.title,
  r.country_id,
  r.published_at,
  count(distinct rv.id)                                    as reviews_count,
  count(distinct s.user_id)                                as saves_count,
  round(avg(rv.rating)::numeric, 2)                        as rating,
  round(((count(rv.id) * coalesce(avg(rv.rating), 0) + 5 * o.mean)
         / (count(rv.id) + 5))::numeric, 3)                as score
from public.routes r
join public.profiles a on a.id = r.author_id
cross join overall o
left join public.route_reviews rv on rv.route_id = r.id
left join public.route_saves   s  on s.route_id  = r.id
where r.is_published
group by r.id, r.author_id, a.handle, a.name, r.title, r.country_id,
         r.published_at, o.mean;

-- ───────────────────────── Топ авторов ─────────────────────────
--
-- Автор ценен не количеством маршрутов, а тем, как их оценили. Поэтому в
-- основе та же сглаженная оценка, что и у маршрутов: пока отзывов мало,
-- автор держится около общей средней и не взлетает с одной пятёркой.
--
-- Маршруты без единого отзыва в счёт идут, но вес им даёт только
-- сохранение: их кто-то забрал себе, значит они не пустые.

create view public.popular_authors as
select
  p.id,
  p.handle,
  p.name,
  p.avatar_path,
  p.bio,
  count(distinct pr.id)                                   as routes_count,
  coalesce(sum(pr.reviews_count), 0)                      as reviews_count,
  coalesce(sum(pr.saves_count), 0)                        as saves_count,
  round(avg(pr.score)::numeric, 3)                        as score
from public.profiles p
join public.popular_routes pr on pr.author_id = p.id
group by p.id, p.handle, p.name, p.avatar_path, p.bio;

-- ─────────────────── Профиль при регистрации ───────────────────
--
-- Создаём строку профиля сразу после регистрации, а не при первом открытии
-- экрана: иначе появляется состояние «пользователь есть, профиля нет»,
-- и каждый запрос приходится писать с оглядкой на него.

create function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, handle, name)
  values (
    new.id,
    'u' || substr(replace(new.id::text, '-', ''), 1, 12),
    coalesce(new.raw_user_meta_data->>'name', 'Путешественник')
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
