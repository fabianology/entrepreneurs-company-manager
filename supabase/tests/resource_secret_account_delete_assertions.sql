-- Run only in the isolated scoped-vault fixture after migration 230002.
-- Model the production Auth -> card cascade omitted by the minimal fixture.
alter table public.financial_cards
    add constraint fixture_card_owner_delete_fk
    foreign key (user_id) references auth.users(id) on delete cascade;

insert into public.resource_secret_versions (
    owner_user_id, resource_type, resource_id, company_id,
    key_version, owner_account_key_version, owner_wrapped_resource_key
) values (
    '00000000-0000-0000-0000-000000000001', 'card',
    '40000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000001', 1, 1,
    encode(convert_to(repeat('x', 60), 'utf8'), 'base64')
);

begin;
delete from public.financial_cards
 where id = '40000000-0000-0000-0000-000000000001';
do $$
begin
    if exists (
        select 1 from public.resource_secret_versions
         where resource_type = 'card'
           and resource_id = '40000000-0000-0000-0000-000000000001'
    ) or not exists (
        select 1 from public.resource_secret_audit_events
         where resource_type = 'card'
           and resource_id = '40000000-0000-0000-0000-000000000001'
           and event_type = 'key_retired'
    ) then
        raise exception 'Ordinary card deletion lost its audit or retained its key';
    end if;
end;
$$;
rollback;

begin;
delete from auth.users
 where id = '00000000-0000-0000-0000-000000000001';
do $$
begin
    if exists (select 1 from auth.users where id = '00000000-0000-0000-0000-000000000001')
       or exists (select 1 from public.financial_cards
                   where id = '40000000-0000-0000-0000-000000000001')
       or exists (select 1 from public.resource_secret_versions
                   where resource_type = 'card'
                     and resource_id = '40000000-0000-0000-0000-000000000001')
       or exists (select 1 from public.resource_secret_audit_events
                   where owner_user_id = '00000000-0000-0000-0000-000000000001')
    then
        raise exception 'Owner deletion did not cascade and purge the resource key';
    end if;
end;
$$;
rollback;
