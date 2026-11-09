-- ===== ລະບົບບໍລິຫານວິທະຍາໄລ: ຖານຂໍ້ມູນ (Supabase / PostgreSQL) =====
-- ວິທີໃຊ້: Supabase Dashboard > SQL Editor > ວາງທັງໝົດນີ້ > Run

-- 1) ຕາຕະລາງສົກຮຽນ  (ລ/ດ = id, ສົກຮຽນ = year_name  ຕົວຢ່າງ 2026-2027)
create table if not exists academic_years (
  id         bigint generated always as identity primary key,
  year_name  text not null unique,
  created_at timestamptz default now()
);

-- 2) ຕາຕະລາງປະຫວັດນັກສຶກສາ
create table if not exists students (
  id               bigint generated always as identity primary key,
  academic_year_id bigint not null references academic_years(id) on delete restrict,
  photo_url        text,
  first_name_lo    text not null,   -- ຊື່ (ລາວ)
  last_name_lo     text not null,   -- ນາມສະກຸນ (ລາວ)
  first_name_en    text,            -- ຊື່ (ອັງກິດ)
  last_name_en     text,            -- ນາມສະກຸນ (ອັງກິດ)
  gender           text check (gender in ('ຊາຍ','ຍິງ')),
  dob              date,            -- ວັນເກີດ (ເກັບເປັນວັນທີ)
  dob_lo           text,            -- 01 ກັນຍາ 2000
  dob_en           text,            -- 01 September 2000
  birth_village    text,            -- ບ້ານ
  birth_district   text,            -- ເມືອງ
  birth_province   text,            -- ແຂວງ
  high_school      text,            -- ຈົບ ມ.7 ຈາກ ມ.ສ
  phone            text,
  father_phone     text,
  mother_phone     text,
  emergency_phone  text,
  created_at       timestamptz default now()
);
create index if not exists students_year_idx on students(academic_year_id);

-- 3) ຕາຕະລາງຜູ້ບໍລິຫານ: ມີຊື່ໃນນີ້ເທົ່ານັ້ນ ຈຶ່ງແກ້ໄຂ/ລົບຂໍ້ມູນໄດ້
create table if not exists admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  email      text,
  created_at timestamptz default now()
);
alter table admins enable row level security;   -- ບໍ່ມີ policy = ເອີ້ນຜ່ານ API ໂດຍກົງບໍ່ໄດ້

create or replace function public.is_admin() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

-- 4) ສິດການເຂົ້າເຖິງ: ທຸກຄົນ "ເບິ່ງໄດ້", ສະເພາະຜູ້ບໍລິຫານທີ່ລັອກອິນ "ເພີ່ມ/ແກ້ໄຂ/ລົບ" ໄດ້
alter table academic_years enable row level security;
alter table students       enable row level security;

create policy "public read years"    on academic_years for select using (true);
create policy "public read students" on students       for select using (true);

create policy "admin write years"    on academic_years for all to authenticated using (public.is_admin()) with check (public.is_admin());
-- ທຸກຄົນ "ເພີ່ມ" ນັກສຶກສາໄດ້; ແກ້ໄຂ/ລົບ ໄດ້ສະເພາະຜູ້ບໍລິຫານ
create policy "public insert students" on students for insert to anon, authenticated with check (true);
create policy "admin update students"  on students for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin delete students"  on students for delete to authenticated using (public.is_admin());

-- 5) ບ່ອນເກັບຮູບພາບ
insert into storage.buckets (id, name, public)
values ('student-photos', 'student-photos', true)
on conflict (id) do nothing;

create policy "public read photos" on storage.objects
  for select using (bucket_id = 'student-photos');
create policy "public upload photos" on storage.objects
  for insert to anon, authenticated with check (bucket_id = 'student-photos');
create policy "admin update photos" on storage.objects
  for update to authenticated using (bucket_id = 'student-photos' and public.is_admin());
create policy "admin delete photos" on storage.objects
  for delete to authenticated using (bucket_id = 'student-photos' and public.is_admin());

-- ຕົວຢ່າງສົກຮຽນ
insert into academic_years (year_name) values ('2026-2027') on conflict do nothing;

-- 6) ເພີ່ມຜູ້ບໍລິຫານ: ສ້າງຜູ້ໃຊ້ໃນ Authentication > Users ກ່ອນ ແລ້ວແທນອີເມວລຸ່ມນີ້
-- insert into admins (user_id, email) select id, email from auth.users where email = 'admin@example.com';
