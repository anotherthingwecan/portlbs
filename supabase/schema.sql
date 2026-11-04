-- LBS 포트폴리오 · Supabase 스키마 (calltime-board 프로젝트에 이미 적용됨, 기록용)
-- 콜타임 보드 테이블과 섞이지 않게 lbs_ 접두어로 분리. 주인은 콜타임 보드 PD와 같은 Auth 계정.

-- 주인 이메일 목록 (API로는 아무도 못 읽음). 바꾸려면 여기 이메일을 넣고 Auth에 사용자를 만들면 돼요.
create table public.lbs_owner (email text primary key);
alter table public.lbs_owner enable row level security;
insert into public.lbs_owner (email) values ('sjqwer1234@gmail.com');

create or replace function public.lbs_is_owner() returns boolean
language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from auth.users u
    join public.lbs_owner o on lower(o.email) = lower(u.email)
    where u.id = auth.uid() and u.email_confirmed_at is not null
  );
$$;
revoke all on function public.lbs_is_owner() from public;
grant execute on function public.lbs_is_owner() to anon, authenticated;

-- 사이트 정보 (한 줄)
create table public.lbs_site (
  id int primary key default 1 check (id = 1),
  name text not null default 'LBS',
  tagline text not null default '',
  about text not null default '',
  email text not null default '',
  categories text[] not null default array['Styling','Show','Web','Logo'],
  updated_at timestamptz not null default now()
);
alter table public.lbs_site enable row level security;
create policy "lbs site: anyone reads" on public.lbs_site for select to anon, authenticated using (true);
create policy "lbs site: owner updates" on public.lbs_site for update to authenticated
  using (public.lbs_is_owner()) with check (public.lbs_is_owner());

-- 작업. photos = [{path, thumb, caption, w, h}]
create table public.lbs_works (
  id uuid primary key default gen_random_uuid(),
  title text not null default '',
  client text not null default '',
  made_on date not null default date_trunc('month', now())::date,
  categories text[] not null default '{}',
  description text not null default '',
  link text not null default '',
  photos jsonb not null default '[]'::jsonb,
  cover int not null default 0,
  published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.lbs_works enable row level security;
create policy "lbs works: read published, owner reads all" on public.lbs_works for select to anon, authenticated
  using (published or public.lbs_is_owner());
create policy "lbs works: owner inserts" on public.lbs_works for insert to authenticated with check (public.lbs_is_owner());
create policy "lbs works: owner updates" on public.lbs_works for update to authenticated
  using (public.lbs_is_owner()) with check (public.lbs_is_owner());
create policy "lbs works: owner deletes" on public.lbs_works for delete to authenticated using (public.lbs_is_owner());
create index lbs_works_order_idx on public.lbs_works (made_on desc, created_at desc);

-- 사진: 누구나 링크로 보기(공개 버킷), 주인만 올리기·바꾸기·지우기
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('lbs', 'lbs', true, 10485760, array['image/jpeg','image/png','image/webp']);
create policy "lbs files: owner reads" on storage.objects for select to authenticated
  using (bucket_id = 'lbs' and public.lbs_is_owner());
create policy "lbs files: owner uploads" on storage.objects for insert to authenticated
  with check (bucket_id = 'lbs' and public.lbs_is_owner());
create policy "lbs files: owner updates" on storage.objects for update to authenticated
  using (bucket_id = 'lbs' and public.lbs_is_owner()) with check (bucket_id = 'lbs' and public.lbs_is_owner());
create policy "lbs files: owner deletes" on storage.objects for delete to authenticated
  using (bucket_id = 'lbs' and public.lbs_is_owner());
