-- ===== Patch: ສະເພາະຜູ້ບໍລິຫານຈຶ່ງແກ້ໄຂ/ລົບໄດ້ (ສຳລັບຖານຂໍ້ມູນທີ່ສ້າງແລ້ວ) =====
-- ວິທີໃຊ້: Supabase > SQL Editor > ວາງ > ແກ້ອີເມວທ້າຍໄຟລ໌ > Run

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

-- ປ່ຽນ policy ເກົ່າ (ໃຜລັອກອິນກໍແກ້ໄຂໄດ້) ເປັນ: ສະເພາະຜູ້ບໍລິຫານ
drop policy if exists "admin write years"     on academic_years;
drop policy if exists "admin update students" on students;
drop policy if exists "admin delete students" on students;
drop policy if exists "admin update photos"   on storage.objects;
drop policy if exists "admin delete photos"   on storage.objects;

create policy "admin write years"     on academic_years for all    to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin update students" on students       for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin delete students" on students       for delete to authenticated using (public.is_admin());
create policy "admin update photos"   on storage.objects for update to authenticated using (bucket_id = 'student-photos' and public.is_admin());
create policy "admin delete photos"   on storage.objects for delete to authenticated using (bucket_id = 'student-photos' and public.is_admin());

-- ສຳຄັນ: ເພີ່ມບັນຊີຜູ້ບໍລິຫານຂອງທ່ານ (ແທນອີເມວ) ບໍ່ດັ່ງນັ້ນຈະແກ້ໄຂຂໍ້ມູນບໍ່ໄດ້
insert into admins (user_id, email)
select id, email from auth.users where email = 'admin@example.com'
on conflict do nothing;
