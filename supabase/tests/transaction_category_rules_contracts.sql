-- Run against a disposable database with the category-rule migration applied.
begin;

insert into auth.users(id) values
    ('15000000-0000-0000-0000-000000000001'),
    ('15000000-0000-0000-0000-000000000002');

select set_config('request.jwt.claim.sub', '15000000-0000-0000-0000-000000000001', true);
set local role authenticated;

insert into public.plaid_transaction_category_rules (
    user_id, scope_key, merchant_key, merchant_name, category_primary
) values (
    '15000000-0000-0000-0000-000000000001',
    'company:25000000-0000-0000-0000-000000000001',
    'ayso soccer',
    'AYSO Soccer',
    'Kids Sports'
);

do $$ begin
    if not exists (
        select 1 from public.plaid_transaction_category_rules
        where merchant_key = 'ayso soccer' and category_primary = 'Kids Sports'
    ) then
        raise exception 'Owner could not read saved category rule';
    end if;

    begin
        insert into public.plaid_transaction_category_rules (
            user_id, scope_key, merchant_key, merchant_name, category_primary
        ) values (
            '15000000-0000-0000-0000-000000000002',
            'unassigned',
            'other merchant',
            'Other Merchant',
            'Other'
        );
        raise exception 'Cross-owner category rule insert was allowed';
    exception when insufficient_privilege then null;
    end;
end $$;

reset role;
select set_config('request.jwt.claim.sub', '15000000-0000-0000-0000-000000000002', true);
set local role authenticated;

do $$ begin
    if exists (select 1 from public.plaid_transaction_category_rules) then
        raise exception 'Category rules leaked across owners';
    end if;
end $$;

rollback;
