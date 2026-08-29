-- Keep recurring-charge suggestions company-scoped and resolve them after the
-- matching subscription is created. Prefer the card as the navigation source
-- when the Plaid account is attached to a financial card.

create or replace function public.refresh_miloom_subscription_insights(p_user_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
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

    -- A created subscription resolves only suggestions belonging to the same
    -- company. Match both the current fingerprint and legacy title format.
    update public.obligations o
       set state = 'handled',
           updated_at = now()
     where o.kind = 'new_recurring_charge'
       and o.state in ('open', 'snoozed')
       and (p_user_id is null or o.owner_user_id = p_user_id)
       and exists (
           select 1
             from public.subscriptions s
            where s.user_id = o.owner_user_id
              and s.company_id is not distinct from o.company_id
              and (
                  regexp_replace(lower(s.name), '[^a-z0-9]', '', 'g') = split_part(o.fingerprint, ':', 3)
                  or regexp_replace(
                         lower(regexp_replace(coalesce(s.plaid_stream_id, ''), '^detected_', '')),
                         '[^a-z0-9]', '', 'g'
                     ) = split_part(o.fingerprint, ':', 3)
                  or regexp_replace(lower(s.name), '[^a-z0-9]', '', 'g') =
                     regexp_replace(lower(split_part(o.title, ' may be a subscription', 1)), '[^a-z0-9]', '', 'g')
              )
       );

    insert into public.obligations (
        owner_user_id, company_id, source_type, source_id, kind, due_at,
        severity, title, summary, action_type, fingerprint
    )
    select r.user_id,
           r.company_id,
           case when c.id is null then 'institution' else 'card' end,
           coalesce(c.id, r.institution_id),
           'new_recurring_charge',
           now(),
           'attention',
           r.display_name || ' may be a subscription',
           r.occurrences || ' similar payments averaging ' ||
               trim(to_char(r.average_amount, 'FM$999999990.00')) ||
               ' appear to recur ' || lower(r.frequency) || '.',
           'review_recurring_charge',
           'new_recurring:' || r.account_id || ':' || r.merchant_key
      from (
          select t.user_id,
                 t.company_id,
                 coalesce(t.institution_id, p.institution_id) as institution_id,
                 coalesce(t.account_id, '') as account_id,
                 regexp_replace(lower(coalesce(t.merchant_name, t.name, '')), '[^a-z0-9]', '', 'g') as merchant_key,
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
             and lower(coalesce(t.merchant_name, t.name, '')) !~
                 '(^|[^a-z])(zelle|atm|withdrawal|payment to|autopay|monthly payment|loan payment|credit card payment|transfer to|transfer from|mobile check deposit)([^a-z]|$)'
             and lower(coalesce(t.category::text, '')) !~
                 '(transfer|payment|cash|deposit|withdrawal)'
             and (p_user_id is null or t.user_id = p_user_id)
           group by t.user_id,
                    t.company_id,
                    coalesce(t.institution_id, p.institution_id),
                    coalesce(t.account_id, ''),
                    regexp_replace(lower(coalesce(t.merchant_name, t.name, '')), '[^a-z0-9]', '', 'g')
          having count(*) >= 2
             and max(t.date) - min(t.date) >= 15
             and max(t.date) >= current_date - 45
             and avg(abs(t.amount)) > 0
             and coalesce(stddev_pop(abs(t.amount)) / nullif(avg(abs(t.amount)), 0), 0) < 0.25
      ) r
      left join public.financial_cards c
        on c.user_id = r.user_id
       and c.company_id is not distinct from r.company_id
       and c.plaid_account_id = r.account_id
     where coalesce(c.id, r.institution_id) is not null
       and r.merchant_key <> ''
       and not exists (
           select 1
             from public.subscriptions s
            where s.user_id = r.user_id
              and s.company_id is not distinct from r.company_id
              and (
                  regexp_replace(lower(s.name), '[^a-z0-9]', '', 'g') = r.merchant_key
                  or regexp_replace(
                         lower(regexp_replace(coalesce(s.plaid_stream_id, ''), '^detected_', '')),
                         '[^a-z0-9]', '', 'g'
                     ) = r.merchant_key
              )
       )
    on conflict (owner_user_id, fingerprint) do update set
        company_id = excluded.company_id,
        source_type = excluded.source_type,
        source_id = excluded.source_id,
        title = excluded.title,
        summary = excluded.summary,
        updated_at = now();
end;
$$;

revoke all on function public.refresh_miloom_subscription_insights(uuid) from public;
grant execute on function public.refresh_miloom_subscription_insights(uuid) to service_role;
