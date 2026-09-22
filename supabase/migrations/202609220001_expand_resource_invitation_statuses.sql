-- Forward repair for environments where canonical resource access was applied
-- before the legacy Pending/Accepted invitation constraint was replaced.

begin;

update public.resource_invitations
   set status = case
       when status in ('Pending', 'Accepted', 'Declined', 'Revoked') then status
       else 'Pending'
   end;

alter table public.resource_invitations
    drop constraint if exists resource_invitations_status_check;
alter table public.resource_invitations
    add constraint resource_invitations_status_check
    check (status in ('Pending', 'Accepted', 'Declined', 'Revoked'));

commit;
