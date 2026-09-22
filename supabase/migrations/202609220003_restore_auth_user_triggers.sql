-- Restore app-owned triggers attached to Supabase's managed auth.users table.
-- A public/private schema-only baseline does not include these cross-schema
-- trigger objects, even though their functions live in public.

begin;

drop trigger if exists business_expense_user_cleanup on auth.users;
create trigger business_expense_user_cleanup
before delete on auth.users
for each row execute function public.queue_business_expense_user_files();

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- The legacy signup trigger accepted every pending invitation immediately.
-- Keep it disabled so the recipient-bound Phase 2 Accept/Decline flow remains
-- the only path that converts an invitation into direct access.
drop trigger if exists on_auth_user_created_invitations on auth.users;

-- Backfill only missing profile rows for accounts created before the triggers
-- were restored. Existing profile data is never overwritten.
insert into public.profiles (id, email, full_name, avatar_url)
select
    auth_user.id,
    auth_user.email,
    auth_user.raw_user_meta_data->>'full_name',
    auth_user.raw_user_meta_data->>'avatar_url'
from auth.users auth_user
left join public.profiles profile on profile.id = auth_user.id
where profile.id is null
on conflict (id) do nothing;

commit;
