-- Share revocation is only one lifecycle path. Block, resource move, deletion
-- and ownership changes must not leave a reusable credential wrap behind.
begin;

create or replace function public.miloom_lock_resource_secret_on_block()
returns trigger
language plpgsql security definer set search_path = ''
as $$
begin
    update public.resource_secret_versions sv
       set state = 'rotation_required'
     where sv.owner_user_id = new.owner_user_id and sv.state = 'active'
       and exists (
           select 1 from public.resource_secret_device_wraps w
           join auth.users u on u.id = w.recipient_user_id
            where w.resource_type = sv.resource_type
              and w.resource_id = sv.resource_id
              and w.key_version = sv.key_version
              and w.grant_status = 'active'
              and (w.recipient_user_id = new.blocked_user_id
                   or lower(u.email) = lower(new.blocked_email))
       );
    return null;
end;
$$;
create trigger lock_resource_secret_on_block
after insert or update of blocked_email, blocked_user_id on public.resource_access_blocks
for each row execute function public.miloom_lock_resource_secret_on_block();
revoke all on function public.miloom_lock_resource_secret_on_block()
    from public, anon, authenticated;

-- Preexisting blocks are also enforced when this migration is installed.
update public.resource_secret_versions sv
   set state = 'rotation_required'
 where sv.state = 'active' and exists (
     select 1 from public.resource_secret_device_wraps w
     join auth.users u on u.id = w.recipient_user_id
     join public.resource_access_blocks b on b.owner_user_id = sv.owner_user_id
      where w.resource_type = sv.resource_type and w.resource_id = sv.resource_id
        and w.key_version = sv.key_version and w.grant_status = 'active'
        and (w.recipient_user_id = b.blocked_user_id
             or lower(u.email) = lower(b.blocked_email))
 );

create or replace function public.miloom_guard_resource_secret_owner_transfer()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := case tg_table_name
        when 'financial_cards' then 'card'
        when 'subscriptions' then 'subscription'
        when 'institutions' then 'institution' end;
begin
    if new.user_id is distinct from old.user_id and exists (
        select 1 from public.resource_secret_versions sv
         where sv.resource_type = v_type and sv.resource_id = old.id
    ) then
        raise exception using errcode = '42501',
            message = 'RESOURCE_SECRET_OWNERSHIP_TRANSFER_NOT_READY';
    end if;
    return new;
end;
$$;
create trigger zzx_miloom_guard_secret_owner_transfer
before update of user_id on public.subscriptions
for each row execute function public.miloom_guard_resource_secret_owner_transfer();
create trigger zzx_miloom_guard_secret_owner_transfer
before update of user_id on public.financial_cards
for each row execute function public.miloom_guard_resource_secret_owner_transfer();
create trigger zzx_miloom_guard_secret_owner_transfer
before update of user_id on public.institutions
for each row execute function public.miloom_guard_resource_secret_owner_transfer();
revoke all on function public.miloom_guard_resource_secret_owner_transfer()
    from public, anon, authenticated;

create or replace function public.miloom_move_resource_secret_company()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := case tg_table_name
        when 'financial_cards' then 'card'
        when 'subscriptions' then 'subscription'
        when 'institutions' then 'institution' end;
begin
    if new.company_id is distinct from old.company_id then
        if not exists (select 1 from public.companies c
            where c.id = new.company_id and c.user_id = new.user_id) then
            raise exception using errcode = '42501',
                message = 'RESOURCE_SECRET_COMPANY_NOT_OWNED';
        end if;
        update public.resource_secret_versions sv
           set company_id = new.company_id,
               state = case when sv.state = 'active' then 'rotation_required'
                            else sv.state end
         where sv.resource_type = v_type and sv.resource_id = new.id
           and sv.owner_user_id = new.user_id;
    end if;
    return null;
end;
$$;
create trigger move_resource_secret_company
after update of company_id on public.subscriptions
for each row execute function public.miloom_move_resource_secret_company();
create trigger move_resource_secret_company
after update of company_id on public.financial_cards
for each row execute function public.miloom_move_resource_secret_company();
create trigger move_resource_secret_company
after update of company_id on public.institutions
for each row execute function public.miloom_move_resource_secret_company();
revoke all on function public.miloom_move_resource_secret_company()
    from public, anon, authenticated;

create or replace function public.miloom_purge_deleted_resource_secrets()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_type text := case tg_table_name
        when 'financial_cards' then 'card'
        when 'subscriptions' then 'subscription'
        when 'institutions' then 'institution' end;
begin
    insert into public.resource_secret_audit_events (
        owner_user_id, actor_user_id, resource_type, resource_id, key_version, event_type
    )
    select sv.owner_user_id, auth.uid(), sv.resource_type, sv.resource_id,
           sv.key_version, 'key_retired'
      from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = old.id
       and sv.owner_user_id = old.user_id and sv.state <> 'retired';
    delete from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = old.id
       and sv.owner_user_id = old.user_id;
    return old;
end;
$$;
create trigger purge_deleted_resource_secrets
before delete on public.subscriptions
for each row execute function public.miloom_purge_deleted_resource_secrets();
create trigger purge_deleted_resource_secrets
before delete on public.financial_cards
for each row execute function public.miloom_purge_deleted_resource_secrets();
create trigger purge_deleted_resource_secrets
before delete on public.institutions
for each row execute function public.miloom_purge_deleted_resource_secrets();
revoke all on function public.miloom_purge_deleted_resource_secrets()
    from public, anon, authenticated;

notify pgrst, 'reload schema';
commit;
