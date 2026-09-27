-- Account deletion cascades to financial resources after auth.users is gone.
-- The resource-purge trigger must not insert an audit event that still refers
-- to that deleted user; the FK would roll back the entire account deletion.
-- Ordinary resource deletion retains its key-retired audit event.
begin;

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
       and sv.owner_user_id = old.user_id and sv.state <> 'retired'
       and exists (select 1 from auth.users au where au.id = sv.owner_user_id);

    delete from public.resource_secret_versions sv
     where sv.resource_type = v_type and sv.resource_id = old.id
       and sv.owner_user_id = old.user_id;
    return old;
end;
$$;

revoke all on function public.miloom_purge_deleted_resource_secrets()
    from public, anon, authenticated;

commit;
