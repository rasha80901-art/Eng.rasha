-- شغّلي هذا الملف مرة واحدة في Supabase > SQL Editor
-- الهدف: محاكاة توعوية داخلية آمنة
-- لا نجمع كلمات مرور أو OTP أو بيانات بنكية

create extension if not exists pgcrypto;

create table if not exists public.simulation_participants (
  id uuid primary key default gen_random_uuid(),
  display_name text,
  participant_token text unique not null default encode(gen_random_bytes(16),'hex'),
  campaign_name text default 'سحب الأجهزة الذكية - حملة توعوية بالأمن السيبراني',
  clicked_at timestamptz,
  training_completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.simulation_admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);

alter table public.simulation_participants enable row level security;
alter table public.simulation_admins enable row level security;

revoke all on public.simulation_participants from anon;
revoke all on public.simulation_admins from anon;

drop policy if exists "admins can read participants" on public.simulation_participants;
create policy "admins can read participants"
on public.simulation_participants
for select
to authenticated
using (
  exists (
    select 1 from public.simulation_admins a
    where a.user_id = auth.uid()
  )
);

create or replace function public.record_click(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.simulation_participants
  set clicked_at = coalesce(clicked_at, now())
  where participant_token = p_token;
end;
$$;

create or replace function public.complete_training(p_token text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.simulation_participants
  set training_completed_at = coalesce(training_completed_at, now())
  where participant_token = p_token
    and clicked_at is not null;
end;
$$;

revoke all on function public.record_click(text) from public;
revoke all on function public.complete_training(text) from public;
grant execute on function public.record_click(text) to anon, authenticated;
grant execute on function public.complete_training(text) to anon, authenticated;

-- أمثلة إضافة مشاركين:
-- insert into public.simulation_participants(display_name) values
-- ('الموظف 1'), ('الموظف 2'), ('الموظف 3');

-- بعد إنشاء مستخدم المشرف من Authentication > Users
-- انسخي UUID الخاص به وشغّلي:
-- insert into public.simulation_admins(user_id) values ('PUT_ADMIN_USER_UUID_HERE');

-- لاستخراج الروابط:
-- select
--   display_name,
--   participant_token,
--   'https://YOUR-SITE.netlify.app/?t=' || participant_token as campaign_link
-- from public.simulation_participants
-- order by created_at;
