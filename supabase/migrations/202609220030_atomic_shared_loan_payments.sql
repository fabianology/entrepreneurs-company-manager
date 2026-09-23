-- Atomic loan + ledger saves. Stage before shipping the native RPC client.
-- Existing owner REST writes remain compatible and invalidate stale snapshots;
-- collaborator ledger writes go through the authorized transaction only.
begin;

alter table public.loans add column revision bigint not null default 0;

create function public.miloom_loan_revision_guard()
returns trigger language plpgsql set search_path = '' as $$
begin
    if tg_op = 'INSERT' then
        new.revision := 0;
    else
        if new.user_id is distinct from old.user_id
           or (new.company_id is distinct from old.company_id and (
               auth.uid() is distinct from old.user_id
               or not exists (select 1 from public.companies c
                   where c.id = new.company_id and c.user_id = old.user_id)
           )) then
            raise exception using errcode = '42501', message = 'LOAN_OWNERSHIP_IMMUTABLE';
        end if;
        new.revision := old.revision + 1;
    end if;
    return new;
end;
$$;
create trigger miloom_loan_revision_guard before insert or update on public.loans
for each row execute function public.miloom_loan_revision_guard();
revoke all on function public.miloom_loan_revision_guard() from public, anon, authenticated;

-- Parent serialization also covers legacy owner payment writes. A forged
-- user_id must never make a payment on someone else's loan readable/writable.
create function public.miloom_loan_payment_revision_guard()
returns trigger language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
    if tg_op = 'UPDATE' and (new.id is distinct from old.id
        or new.loan_id is distinct from old.loan_id
        or new.user_id is distinct from old.user_id) then
        raise exception using errcode = '42501', message = 'LOAN_PAYMENT_IDENTITY_IMMUTABLE';
    end if;
    if tg_op = 'DELETE' then
        update public.loans set revision = revision where id = old.loan_id;
        return old;
    end if;
    update public.loans set revision = revision where id = new.loan_id
        returning user_id into v_owner;
    if v_owner is null or new.user_id is distinct from v_owner then
        raise exception using errcode = '42501', message = 'LOAN_PAYMENT_OWNER_MISMATCH';
    end if;
    return new;
end;
$$;
create trigger miloom_loan_payment_revision_guard
before insert or update or delete on public.loan_payments
for each row execute function public.miloom_loan_payment_revision_guard();
revoke all on function public.miloom_loan_payment_revision_guard() from public, anon, authenticated;

create function public.miloom_loan_actor_allowed(
    p_id uuid, p_company uuid, p_owner uuid, p_write boolean
) returns boolean language sql stable security definer set search_path = '' as $$
    select auth.uid() is not null and (
        auth.uid() = p_owner or (
            not exists (
                select 1 from public.resource_access_blocks b
                join auth.users u on u.id = auth.uid()
                where b.owner_user_id = p_owner
                  and (b.blocked_user_id = u.id or lower(b.blocked_email) = lower(u.email))
            ) and case when p_write
                then public.miloom_can_edit_resource('loan', p_id, p_company, p_owner)
                else public.miloom_can_read_resource('loan', p_id, p_company, p_owner)
            end
        )
    );
$$;
revoke all on function public.miloom_loan_actor_allowed(uuid,uuid,uuid,boolean)
    from public, anon, authenticated;

create function public.miloom_can_read_loan_payment(p_loan_id uuid, p_owner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
    select exists (select 1 from public.loans l where l.id = p_loan_id
        and l.user_id = p_owner
        and public.miloom_loan_actor_allowed(l.id, l.company_id, l.user_id, false));
$$;
revoke all on function public.miloom_can_read_loan_payment(uuid,uuid) from public, anon;
grant execute on function public.miloom_can_read_loan_payment(uuid,uuid) to authenticated;
alter table public.loan_payments enable row level security;
create policy miloom_loan_payment_read on public.loan_payments for select to authenticated
using (public.miloom_can_read_loan_payment(loan_id, user_id));
create policy miloom_loan_payment_read_boundary on public.loan_payments
as restrictive for select to anon, authenticated
using (public.miloom_can_read_loan_payment(loan_id, user_id));
create policy miloom_loan_payment_insert_boundary on public.loan_payments
as restrictive for insert to anon, authenticated
with check (auth.uid() = user_id and public.miloom_can_read_loan_payment(loan_id, user_id));
create policy miloom_loan_payment_update_boundary on public.loan_payments
as restrictive for update to anon, authenticated
using (auth.uid() = user_id and public.miloom_can_read_loan_payment(loan_id, user_id))
with check (auth.uid() = user_id and public.miloom_can_read_loan_payment(loan_id, user_id));
create policy miloom_loan_payment_delete_boundary on public.loan_payments
as restrictive for delete to anon, authenticated
using (auth.uid() = user_id and public.miloom_can_read_loan_payment(loan_id, user_id));

-- One statement/snapshot: separate loan and ledger fetches could otherwise
-- pair a current revision with an out-of-date ledger and lose payments.
create function public.miloom_read_loans()
returns table(loan jsonb, payments jsonb)
language sql stable security definer set search_path = '' as $$
    select to_jsonb(l), coalesce((select jsonb_agg(to_jsonb(p) order by p.id)
        from public.loan_payments p where p.loan_id = l.id and p.user_id = l.user_id), '[]'::jsonb)
    from public.loans l
    where public.miloom_loan_actor_allowed(l.id, l.company_id, l.user_id, false)
    order by l.id;
$$;
revoke all on function public.miloom_read_loans() from public, anon;
grant execute on function public.miloom_read_loans() to authenticated;

create function public.miloom_save_loan(
    p_loan jsonb, p_payments jsonb, p_expected_revision bigint
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
    v_old public.loans%rowtype;
    v_next public.loans%rowtype;
    v_final public.loans%rowtype;
    v_owner uuid;
    v_exists boolean;
    v_payment public.loan_payments%rowtype;
    v_json jsonb;
begin
    if auth.uid() is null then
        raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
    end if;
    if jsonb_typeof(p_loan) is distinct from 'object'
       or jsonb_typeof(p_payments) is distinct from 'array' then
        raise exception using errcode = '22023', message = 'INVALID_LOAN_SAVE';
    end if;
    if jsonb_array_length(p_payments) > 10000 then
        raise exception using errcode = '22023', message = 'LOAN_PAYMENT_LIMIT';
    end if;
    v_next := jsonb_populate_record(null::public.loans, p_loan);
    select * into v_old from public.loans where id = v_next.id for update;
    v_exists := found;
    if v_exists then
        if not public.miloom_loan_actor_allowed(v_old.id, v_old.company_id, v_old.user_id, true) then
            raise exception using errcode = '42501', message = 'LOAN_ACCESS_DENIED';
        end if;
        if p_expected_revision is distinct from v_old.revision then
            raise exception using errcode = '40001', message = 'LOAN_CHANGED_REFRESH_REQUIRED';
        end if;
        if v_next.user_id is distinct from v_old.user_id
           or v_next.company_id is distinct from v_old.company_id
           or (auth.uid() <> v_old.user_id and v_next.plaid_account_id is distinct from v_old.plaid_account_id) then
            raise exception using errcode = '42501', message = 'LOAN_IDENTITY_MISMATCH';
        end if;
    else
        select user_id into v_owner from public.companies where id = v_next.company_id;
        -- Null resource id deliberately excludes stale exact-item grants from creation.
        if v_owner is null or v_next.user_id is distinct from v_owner
           or not public.miloom_loan_actor_allowed(null, v_next.company_id, v_owner, true)
           or (auth.uid() <> v_owner and v_next.plaid_account_id is not null) then
            raise exception using errcode = '42501', message = 'LOAN_ACCESS_DENIED';
        end if;
        if p_expected_revision is not null then
            raise exception using errcode = '40001', message = 'LOAN_CHANGED_REFRESH_REQUIRED';
        end if;
    end if;
    if v_next.id is null or nullif(btrim(v_next.name), '') is null then
        raise exception using errcode = '22023', message = 'INVALID_LOAN_NAME';
    end if;
    if (select count(distinct value->>'id') from jsonb_array_elements(p_payments))
       <> jsonb_array_length(p_payments) then
        raise exception using errcode = '22023', message = 'DUPLICATE_LOAN_PAYMENT';
    end if;
    for v_json in select value from jsonb_array_elements(p_payments) loop
        if jsonb_typeof(v_json) <> 'object' then
            raise exception using errcode = '22023', message = 'INVALID_LOAN_PAYMENT';
        end if;
        v_payment := jsonb_populate_record(null::public.loan_payments, v_json);
        if v_payment.id is null or v_payment.loan_id is distinct from v_next.id
           or v_payment.user_id is distinct from v_next.user_id
           or v_payment.date is null or not isfinite(v_payment.date)
           or v_payment.amount is null or v_payment.amount <= 0
           or v_payment.amount::text in ('NaN', 'Infinity', '-Infinity')
           or exists (select 1 from public.loan_payments p where p.id = v_payment.id
               and (p.loan_id <> v_next.id or p.user_id <> v_next.user_id)) then
            raise exception using errcode = '22023', message = 'INVALID_LOAN_PAYMENT';
        end if;
    end loop;

    if v_exists then
        update public.loans set
            name = v_next.name, role = v_next.role, lender = v_next.lender,
            principal_amount = v_next.principal_amount, remaining_balance = v_next.remaining_balance,
            interest_type = v_next.interest_type, interest_rate = v_next.interest_rate,
            term = v_next.term, term_years = v_next.term_years, term_months = v_next.term_months,
            schedule_frequency = v_next.schedule_frequency, monthly_payment = v_next.monthly_payment,
            start_date = v_next.start_date, maturity_date = v_next.maturity_date,
            next_payment_at = v_next.next_payment_at, paid_off_date = v_next.paid_off_date,
            status = v_next.status, notes = v_next.notes, plaid_account_id = v_next.plaid_account_id
        where id = v_old.id;
    else
        insert into public.loans (id,user_id,company_id,name,role,lender,principal_amount,
            remaining_balance,interest_type,interest_rate,term,term_years,term_months,
            schedule_frequency,monthly_payment,start_date,maturity_date,next_payment_at,
            paid_off_date,status,notes,plaid_account_id)
        values (v_next.id,v_next.user_id,v_next.company_id,v_next.name,v_next.role,v_next.lender,
            v_next.principal_amount,v_next.remaining_balance,v_next.interest_type,v_next.interest_rate,
            v_next.term,v_next.term_years,v_next.term_months,v_next.schedule_frequency,
            v_next.monthly_payment,v_next.start_date,v_next.maturity_date,v_next.next_payment_at,
            v_next.paid_off_date,v_next.status,v_next.notes,v_next.plaid_account_id);
    end if;
    delete from public.loan_payments where loan_id = v_next.id;
    insert into public.loan_payments(id,user_id,loan_id,date,amount,source)
    select p.id,p.user_id,p.loan_id,p.date,p.amount,p.source
    from jsonb_populate_recordset(null::public.loan_payments, p_payments) p;
    select * into v_final from public.loans where id = v_next.id;
    return jsonb_build_object('loan', to_jsonb(v_final), 'payments', coalesce((
        select jsonb_agg(to_jsonb(p) order by p.id) from public.loan_payments p
        where p.loan_id = v_next.id and p.user_id = v_next.user_id
    ), '[]'::jsonb));
end;
$$;
revoke all on function public.miloom_save_loan(jsonb,jsonb,bigint) from public, anon;
grant execute on function public.miloom_save_loan(jsonb,jsonb,bigint) to authenticated;

notify pgrst, 'reload schema';
commit;
