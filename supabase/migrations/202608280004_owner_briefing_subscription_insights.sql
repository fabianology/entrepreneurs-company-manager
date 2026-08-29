-- Keep Owner Briefing useful when explicit renewal timestamps are missing and
-- surface credible recurring charges for a full monthly billing window.

create or replace function public.miloom_next_subscription_renewal(
    p_value text,
    p_cycle text,
    p_reference_date date default current_date
)
returns timestamptz
language plpgsql
stable
set search_path = public
as $$
declare
    v_target date;
    v_day integer;
    v_month_start date;
    v_last_day integer;
begin
    if nullif(btrim(p_value), '') is null then
        return null;
    end if;

    if lower(coalesce(p_cycle, 'monthly')) = 'yearly' then
        if btrim(p_value) !~* '^[a-z]{3,9}[[:space:]]+[0-9]{1,2}$' then
            return null;
        end if;
        v_target := to_date(btrim(p_value) || ' ' || extract(year from p_reference_date)::integer, 'Mon DD YYYY');
        if v_target < p_reference_date then
            v_target := (v_target + interval '1 year')::date;
        end if;
        return v_target::timestamp at time zone 'UTC';
    end if;

    if btrim(p_value) !~ '^[0-9]{1,2}$' then
        return null;
    end if;

    v_day := btrim(p_value)::integer;
    if v_day < 1 or v_day > 31 then
        return null;
    end if;

    v_month_start := date_trunc('month', p_reference_date)::date;
    v_last_day := extract(day from (v_month_start + interval '1 month - 1 day'))::integer;
    v_target := v_month_start + (least(v_day, v_last_day) - 1);

    if v_target < p_reference_date then
        v_month_start := (v_month_start + interval '1 month')::date;
        v_last_day := extract(day from (v_month_start + interval '1 month - 1 day'))::integer;
        v_target := v_month_start + (least(v_day, v_last_day) - 1);
    end if;

    return v_target::timestamp at time zone 'UTC';
exception when others then
    return null;
end;
$$;

create or replace function public.refresh_miloom_subscription_insights(p_user_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    -- The legacy next_renewal field is what the current subscription editor
    -- writes. Materialize/advance its typed timestamp before obligations refresh.
    with calculated as (
        select s.id,
               public.miloom_next_subscription_renewal(
                   s.next_renewal,
                   s.billing_cycle,
                   current_date
               ) as renewal_at
          from public.subscriptions s
         where (p_user_id is null or s.user_id = p_user_id)
           and lower(coalesce(s.status, 'active')) not in ('cancelled', 'canceled', 'paused')
           and (s.next_renewal_at is null or s.next_renewal_at < now())
    )
    update public.subscriptions s
       set next_renewal_at = calculated.renewal_at
      from calculated
     where s.id = calculated.id
       and calculated.renewal_at is not null;

    -- Two or more similarly sized charges spanning at least 15 days form a
    -- candidate. Keep monthly candidates visible even when the latest charge
    -- was more than seven days ago.
    insert into public.obligations (
        owner_user_id, company_id, source_type, source_id, kind, due_at,
        severity, title, summary, action_type, fingerprint
    )
    select r.user_id, r.company_id, 'institution', r.source_id, 'new_recurring_charge', now(),
           'attention', r.display_name || ' may be a subscription',
           r.occurrences || ' similar payments averaging ' ||
               trim(to_char(r.average_amount, 'FM$999999990.00')) ||
               ' appear to recur ' || lower(r.frequency) || '.',
           'review_recurring_charge', 'new_recurring:' || r.account_id || ':' || r.merchant_key
      from (
          select t.user_id,
                 t.company_id,
                 coalesce(t.institution_id, p.institution_id) as source_id,
                 coalesce(t.account_id, '') as account_id,
                 lower(regexp_replace(coalesce(t.merchant_name, t.name, ''), '[^a-z0-9]', '', 'g')) as merchant_key,
                 (array_agg(coalesce(t.merchant_name, t.name) order by t.date desc))[1] as display_name,
                 max(t.date) as last_date,
                 count(*) as occurrences,
                 avg(abs(t.amount)) as average_amount,
                 case when max(t.date) - min(t.date) >= 300 then 'Yearly' else 'Monthly' end as frequency,
                 stddev_pop(abs(t.amount)) as amount_deviation
            from public.plaid_transactions t
            join public.plaid_items p on p.id = t.plaid_item_id
           where t.pending = false
             and coalesce(t.merchant_name, t.name, '') <> ''
             and (p_user_id is null or t.user_id = p_user_id)
           group by t.user_id,
                    t.company_id,
                    coalesce(t.institution_id, p.institution_id),
                    coalesce(t.account_id, ''),
                    lower(regexp_replace(coalesce(t.merchant_name, t.name, ''), '[^a-z0-9]', '', 'g'))
          having count(*) >= 2
             and max(t.date) - min(t.date) >= 15
             and max(t.date) >= current_date - 45
             and avg(abs(t.amount)) > 0
             and coalesce(stddev_pop(abs(t.amount)) / nullif(avg(abs(t.amount)), 0), 0) < 0.25
      ) r
     where r.source_id is not null
       and r.merchant_key <> ''
       and not exists (
           select 1
             from public.subscriptions s
            where s.user_id = r.user_id
              and lower(regexp_replace(s.name, '[^a-z0-9]', '', 'g')) = r.merchant_key
       )
    on conflict (owner_user_id, fingerprint) do update set
        title = excluded.title,
        summary = excluded.summary,
        updated_at = now();
end;
$$;

create or replace function public.refresh_my_miloom_obligations()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
    v_user_id uuid := auth.uid();
begin
    if v_user_id is null then
        raise exception using errcode = '42501', message = 'Authentication required';
    end if;

    perform public.refresh_miloom_subscription_insights(v_user_id);
    perform public.refresh_miloom_obligations(v_user_id);
end;
$$;

revoke all on function public.refresh_miloom_subscription_insights(uuid) from public;
grant execute on function public.refresh_miloom_subscription_insights(uuid) to service_role;
revoke all on function public.refresh_my_miloom_obligations() from public;
grant execute on function public.refresh_my_miloom_obligations() to authenticated;
