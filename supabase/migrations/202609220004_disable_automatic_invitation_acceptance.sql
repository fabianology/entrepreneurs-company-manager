-- Forward repair for staging environments that briefly restored production's
-- legacy signup-time invitation auto-acceptance trigger.

begin;

drop trigger if exists on_auth_user_created_invitations on auth.users;

commit;
