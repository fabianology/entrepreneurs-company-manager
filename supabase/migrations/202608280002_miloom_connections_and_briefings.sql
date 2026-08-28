-- Miloom Pro: deterministic backlinks, suggestions, obligations, and hard cost limits.

create or replace function public.refresh_miloom_connections(p_user_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Every resource belongs to its company. These edges are deterministic.
    insert into public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id,
        relationship_type, origin, confidence, state, inference_key
    )
    select s.user_id, 'subscription', s.id, 'company', s.company_id,
           'belongs_to', 'direct', 1, 'confirmed', 'subscription:company:' || s.company_id
      from public.subscriptions s
     where (p_user_id is null or s.user_id = p_user_id)
    on conflict (owner_user_id, source_type, source_id, target_type, target_id, relationship_type)
    do update set updated_at = now();

    -- Embedded sub-service payment IDs and linked-card IDs remain deterministic.
    insert into public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id,
        relationship_type, origin, confidence, state, inference_key
    )
    select s.user_id, 'subscription', s.id, 'card', case when (service->>'paymentMethodId') ~* '^[0-9a-f-]{36}$' then (service->>'paymentMethodId')::uuid end,
           'paid_by', 'direct', 1, 'confirmed', 'subservice:payment_method_id:' || (service->>'paymentMethodId')
      from public.subscriptions s
      cross join lateral jsonb_array_elements(coalesce(s.sub_services_data, '[]'::jsonb)) service
      join public.financial_cards c on c.id = case when (service->>'paymentMethodId') ~* '^[0-9a-f-]{36}$' then (service->>'paymentMethodId')::uuid end and c.user_id = s.user_id
     where coalesce(service->>'paymentMethodId', '') ~* '^[0-9a-f-]{36}$'
       and (p_user_id is null or s.user_id = p_user_id)
    on conflict (owner_user_id, source_type, source_id, target_type, target_id, relationship_type)
    do update set updated_at = now();

    insert into public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id,
        relationship_type, origin, confidence, state, inference_key
    )
    select i.user_id, 'institution', i.id, 'card', case when (account->>'linkedCardId') ~* '^[0-9a-f-]{36}$' then (account->>'linkedCardId')::uuid end,
           'connected_account', 'direct', 1, 'confirmed', 'institution:linked_card:' || (account->>'linkedCardId')
      from public.institutions i
      cross join lateral jsonb_array_elements(coalesce(i.accounts_data, '[]'::jsonb)) account
      join public.financial_cards c on c.id = case when (account->>'linkedCardId') ~* '^[0-9a-f-]{36}$' then (account->>'linkedCardId')::uuid end and c.user_id = i.user_id
     where coalesce(account->>'linkedCardId', '') ~* '^[0-9a-f-]{36}$'
       and (p_user_id is null or i.user_id = p_user_id)
    on conflict (owner_user_id, source_type, source_id, target_type, target_id, relationship_type)
    do update set updated_at = now();

    -- A unique payment-method name is a suggestion only; names alone never create general edges.
    insert into public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id,
        relationship_type, origin, confidence, state, inference_key
    )
    select s.user_id, 'subscription', s.id, 'card', matched.id,
           'paid_by', 'inferred', 0.8, 'suggested',
           'unique_payment_name:' || lower(trim(s.payment_method)) || ':' || matched.id
      from public.subscriptions s
      join lateral (
          select (array_agg(c.id order by c.id))[1] id
            from public.financial_cards c
           where c.user_id = s.user_id and lower(trim(c.name)) = lower(trim(s.payment_method))
          having count(*) = 1
      ) matched on true
     where s.payment_method_id is null and coalesce(trim(s.payment_method), '') <> ''
       and (p_user_id is null or s.user_id = p_user_id)
    on conflict (owner_user_id, source_type, source_id, target_type, target_id, relationship_type)
    do update set confidence = excluded.confidence, inference_key = excluded.inference_key, updated_at = now();

    -- Shared Plaid account identifiers are strong suggestions but still require confirmation.
    insert into public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id,
        relationship_type, origin, confidence, state, inference_key
    )
    select s.user_id, 'subscription', s.id, 'card', c.id,
           'connected_account', 'inferred', 0.95, 'suggested',
           'plaid_account:' || s.plaid_account_id
      from public.subscriptions s
      join public.financial_cards c on c.user_id = s.user_id and c.plaid_account_id = s.plaid_account_id
     where coalesce(s.plaid_account_id, '') <> ''
       and (p_user_id is null or s.user_id = p_user_id)
    on conflict (owner_user_id, source_type, source_id, target_type, target_id, relationship_type)
    do update set confidence = excluded.confidence, inference_key = excluded.inference_key, updated_at = now();

    insert into public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id,
        relationship_type, origin, confidence, state, inference_key
    )
    select x.user_id, x.resource_type, x.id, 'company', x.company_id,
           case when x.resource_type = 'document' then 'document_for' else 'belongs_to' end,
           'direct', 1, 'confirmed', x.resource_type || ':company:' || x.company_id
      from (
        select user_id, id, company_id, 'institution'::text resource_type from public.institutions
        union all select user_id, id, company_id, 'card' from public.financial_cards
        union all select user_id, id, company_id, 'loan' from public.loans
        union all select user_id, id, company_id, 'document' from public.company_documents
      ) x
     where p_user_id is null or x.user_id = p_user_id
    on conflict (owner_user_id, source_type, source_id, target_type, target_id, relationship_type)
    do update set updated_at = now();

    -- Explicit payment method IDs are facts, not suggestions.
    insert into public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id,
        relationship_type, origin, confidence, state, inference_key
    )
    select s.user_id, 'subscription', s.id, 'card', s.payment_method_id,
           'paid_by', 'direct', 1, 'confirmed', 'subscription:payment_method_id:' || s.payment_method_id
      from public.subscriptions s
      join public.financial_cards c on c.id = s.payment_method_id and c.user_id = s.user_id
     where s.payment_method_id is not null
       and (p_user_id is null or s.user_id = p_user_id)
    on conflict (owner_user_id, source_type, source_id, target_type, target_id, relationship_type)
    do update set updated_at = now();

    -- Matching normalized login email is useful, but must be confirmed by the owner.
    insert into public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id,
        relationship_type, origin, confidence, state, inference_key
    )
    select s.user_id, 'subscription', s.id, 'institution', i.id,
           'uses_login', 'inferred', 0.85, 'suggested',
           'login_email:' || lower(trim(s.login_id))
      from public.subscriptions s
      join public.institutions i
        on i.user_id = s.user_id
       and lower(trim(i.email)) = lower(trim(s.login_id))
     where s.login_id ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
       and (p_user_id is null or s.user_id = p_user_id)
    on conflict (owner_user_id, source_type, source_id, target_type, target_id, relationship_type)
    do update set
        confidence = excluded.confidence,
        inference_key = excluded.inference_key,
        updated_at = now(); -- deliberately preserves rejected/confirmed state

    -- Existing shares become deterministic guest backlinks without exposing email secrets.
    insert into public.resource_connections (
        owner_user_id, source_type, source_id, target_type, target_id,
        relationship_type, origin, confidence, state, inference_key
    )
    select c.user_id, 'company', rs.resource_id, 'collaborator', rs.user_id,
           'shared_with', 'direct', 1, 'confirmed', 'share:' || rs.id
      from public.resource_shares rs
      join public.companies c on c.id = rs.resource_id
     where rs.resource_type = 'company'
       and (p_user_id is null or c.user_id = p_user_id)
    on conflict (owner_user_id, source_type, source_id, target_type, target_id, relationship_type)
    do update set updated_at = now();
end;
$$;

create table if not exists public.briefing_deliveries (
    user_id uuid not null references auth.users(id) on delete cascade,
    local_date date not null,
    delivered_at timestamptz not null default now(),
    item_count integer not null default 0,
    primary key (user_id, local_date)
);

alter table public.briefing_deliveries enable row level security;

create table if not exists public.critical_alert_deliveries (
    user_id uuid not null references auth.users(id) on delete cascade,
    obligation_id uuid not null references public.obligations(id) on delete cascade,
    delivered_at timestamptz not null default now(),
    primary key (user_id, obligation_id)
);

alter table public.critical_alert_deliveries enable row level security;

alter table if exists public.resource_shares
    add column if not exists suspended_at timestamptz;

create or replace function public.miloom_free_company(p_user_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
    select coalesce(
        (select selected_free_company_id from public.user_entitlements where user_id = p_user_id),
        (select id from public.companies where user_id = p_user_id order by last_modified nulls last, id limit 1)
    );
$$;

create or replace function public.enforce_miloom_resource_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.miloom_effective_tier(new.user_id) = 'free'
       and new.company_id <> public.miloom_free_company(new.user_id) then
        raise exception using errcode = 'P0001', message = 'MILOOM_LIMIT:read_only_company';
    end if;
    return new;
end;
$$;

do $$
declare table_name text;
begin
    foreach table_name in array array['subscriptions','institutions','financial_cards','loans','company_documents'] loop
        execute format('drop trigger if exists enforce_miloom_resource_write on public.%I', table_name);
        execute format('create trigger enforce_miloom_resource_write before insert or update on public.%I for each row execute function public.enforce_miloom_resource_write()', table_name);
    end loop;
end;
$$;

create or replace function public.enforce_miloom_company_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if public.miloom_effective_tier(new.user_id) = 'free'
       and new.id <> public.miloom_free_company(new.user_id) then
        raise exception using errcode = 'P0001', message = 'MILOOM_LIMIT:read_only_company';
    end if;
    return new;
end;
$$;

drop trigger if exists enforce_miloom_company_update on public.companies;
create trigger enforce_miloom_company_update
before update on public.companies
for each row execute function public.enforce_miloom_company_update();

create or replace function public.select_miloom_free_resources(p_company_id uuid, p_plaid_item_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare v_user uuid := auth.uid();
begin
    if v_user is null or not exists (select 1 from public.companies where id = p_company_id and user_id = v_user) then
        raise exception 'Invalid Free company selection';
    end if;
    if p_plaid_item_id is not null and not exists (
        select 1 from public.plaid_items where id = p_plaid_item_id and user_id = v_user
    ) then
        raise exception 'Invalid Free Plaid Item selection';
    end if;
    insert into public.user_entitlements(user_id, tier, status, selected_free_company_id, selected_free_plaid_item_id)
    values (v_user, 'free', 'expired', p_company_id, p_plaid_item_id::text)
    on conflict (user_id) do update set
        selected_free_company_id = excluded.selected_free_company_id,
        selected_free_plaid_item_id = excluded.selected_free_plaid_item_id,
        updated_at = now();
end;
$$;

create or replace function public.maintain_miloom_downgrades()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    -- Preserve records and transactions, but remove billable tokens beyond the selected Free Item.
    update public.plaid_items p
       set status = 'suspended', access_token = '', updated_at = now()
      from public.user_entitlements e
     where p.user_id = e.user_id
       and public.miloom_effective_tier(e.user_id) = 'free'
       and e.status in ('expired', 'revoked')
       and p.status = 'active'
       and p.id::text <> coalesce(
           e.selected_free_plaid_item_id,
           (select p2.id::text from public.plaid_items p2 where p2.user_id = e.user_id and p2.status = 'active' order by p2.created_at limit 1)
       );

    update public.resource_shares rs
       set suspended_at = coalesce(rs.suspended_at, now())
      from public.companies c, public.user_entitlements e
     where rs.resource_type = 'company' and rs.resource_id = c.id
       and c.user_id = e.user_id
       and public.miloom_effective_tier(e.user_id) = 'free'
       and e.status in ('expired', 'revoked');

    update public.resource_shares rs
       set suspended_at = null
      from public.companies c, public.user_entitlements e
     where rs.resource_type = 'company' and rs.resource_id = c.id
       and c.user_id = e.user_id
       and public.miloom_effective_tier(e.user_id) = 'pro';
end;
$$;

drop policy if exists "Miloom suspended shares are unavailable" on public.resource_shares;
create policy "Miloom suspended shares are unavailable"
on public.resource_shares as restrictive for select
using (suspended_at is null);

grant execute on function public.select_miloom_free_resources(uuid, uuid) to authenticated;

create or replace function public.refresh_miloom_obligations(p_user_id uuid default null)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
    perform public.refresh_miloom_connections(p_user_id);

    insert into public.obligations (
        owner_user_id, company_id, source_type, source_id, kind, due_at,
        severity, title, summary, action_type, fingerprint
    )
    select s.user_id, s.company_id, 'subscription', s.id, 'subscription_renewal', s.next_renewal_at,
           case when s.next_renewal_at <= now() + interval '1 day' then 'urgent'
                when s.next_renewal_at <= now() + interval '7 days' then 'attention' else 'info' end,
           s.name || ' renews soon',
           s.name || ' renews in ' || greatest(0, ceil(extract(epoch from (s.next_renewal_at - now())) / 86400))::int || ' days.',
           'open_source', 'subscription_renewal:' || s.id || ':' || s.next_renewal_at::date
      from public.subscriptions s
     where s.next_renewal_at between now() and now() + interval '30 days'
       and lower(coalesce(s.status, 'active')) not in ('cancelled', 'canceled')
       and (p_user_id is null or s.user_id = p_user_id)
    on conflict (owner_user_id, fingerprint) do update set
        due_at = excluded.due_at, severity = excluded.severity,
        title = excluded.title, summary = excluded.summary, updated_at = now();

    insert into public.obligations (
        owner_user_id, company_id, source_type, source_id, kind, due_at,
        severity, title, summary, action_type, fingerprint
    )
    select c.user_id, c.company_id, 'card', c.id, 'card_expiration', c.expires_at,
           case when c.expires_at <= now() + interval '7 days' then 'urgent'
                when c.expires_at <= now() + interval '30 days' then 'attention' else 'info' end,
           c.name || ' expires soon',
           c.name || ' expires in ' || greatest(0, ceil(extract(epoch from (c.expires_at - now())) / 86400))::int ||
           ' days and is used by ' || count(distinct s.id) || ' subscriptions across ' ||
           count(distinct s.company_id) || ' companies.',
           'open_source', 'card_expiration:' || c.id || ':' || c.expires_at::date
      from public.financial_cards c
      left join public.subscriptions s on s.payment_method_id = c.id
     where c.expires_at between now() and now() + interval '60 days'
       and (p_user_id is null or c.user_id = p_user_id)
     group by c.user_id, c.company_id, c.id, c.name, c.expires_at
    on conflict (owner_user_id, fingerprint) do update set
        due_at = excluded.due_at, severity = excluded.severity,
        title = excluded.title, summary = excluded.summary, updated_at = now();

    insert into public.obligations (
        owner_user_id, company_id, source_type, source_id, kind, due_at,
        severity, title, summary, action_type, fingerprint
    )
    select c.user_id, c.company_id, 'card', c.id, 'promotional_apr_ending', c.promo_ends,
           case when c.promo_ends <= now() + interval '7 days' then 'urgent' else 'attention' end,
           'Promotional APR ending', c.name || '''s promotional APR ends soon.',
           'open_source', 'promo_apr:' || c.id || ':' || c.promo_ends::date
      from public.financial_cards c
     where c.promo_ends between now() and now() + interval '30 days'
       and (p_user_id is null or c.user_id = p_user_id)
    on conflict (owner_user_id, fingerprint) do update set
        due_at = excluded.due_at, severity = excluded.severity,
        title = excluded.title, summary = excluded.summary, updated_at = now();

    insert into public.obligations (
        owner_user_id, company_id, source_type, source_id, kind, due_at,
        severity, title, summary, action_type, fingerprint
    )
    select d.user_id, d.company_id, 'document', d.id, 'document_expiration', d.expires_at,
           case when d.expires_at <= now() + interval '7 days' then 'urgent'
                when d.expires_at <= now() + interval '30 days' then 'attention' else 'info' end,
           d.name || ' expires soon', 'Review or renew this document before it expires.',
           'open_source', 'document_expiration:' || d.id || ':' || d.expires_at::date
      from public.company_documents d
     where d.expires_at between now() and now() + interval '90 days'
       and (p_user_id is null or d.user_id = p_user_id)
    on conflict (owner_user_id, fingerprint) do update set
        due_at = excluded.due_at, severity = excluded.severity,
        title = excluded.title, summary = excluded.summary, updated_at = now();

    insert into public.obligations (
        owner_user_id, company_id, source_type, source_id, kind, due_at,
        severity, title, summary, action_type, fingerprint
    )
    select l.user_id, l.company_id, 'loan', l.id, x.kind, x.due_at,
           case when x.due_at <= now() + interval '3 days' then 'urgent' else 'attention' end,
           case when x.kind = 'loan_payment' then l.name || ' payment due' else l.name || ' matures soon' end,
           case when x.kind = 'loan_payment' then 'A scheduled loan payment is approaching.' else 'Review the loan before maturity.' end,
           'open_source', x.kind || ':' || l.id || ':' || x.due_at::date
      from public.loans l
      cross join lateral (
          values ('loan_payment'::text, l.next_payment_at, interval '14 days'),
                 ('loan_maturity'::text, l.maturity_date, interval '14 days')
      ) x(kind, due_at, window_size)
     where x.due_at between now() and now() + x.window_size
       and lower(coalesce(l.status, 'active')) <> 'paid off'
       and (p_user_id is null or l.user_id = p_user_id)
    on conflict (owner_user_id, fingerprint) do update set
        due_at = excluded.due_at, severity = excluded.severity,
        title = excluded.title, summary = excluded.summary, updated_at = now();

    insert into public.obligations (
        owner_user_id, company_id, source_type, source_id, kind, due_at,
        severity, title, summary, action_type, fingerprint
    )
    select i.user_id, i.company_id, 'institution', i.id,
           case when i.is_disconnected then 'institution_disconnected' else 'institution_stale' end,
           now(), case when i.is_disconnected then 'urgent' else 'attention' end,
           case when i.is_disconnected then 'Institution needs reconnection' else 'Institution has not synced recently' end,
           'Open the institution to review its connection.', 'open_source',
           case when i.is_disconnected then 'institution_disconnected:' else 'institution_stale:' end || i.id
      from public.institutions i
     where (i.is_disconnected = true or i.last_synced_at < now() - interval '7 days')
       and (p_user_id is null or i.user_id = p_user_id)
    on conflict (owner_user_id, fingerprint) do update set
        severity = excluded.severity, title = excluded.title,
        summary = excluded.summary, updated_at = now();

    -- Two or more similarly sized charges spanning at least 15 days form a recurring candidate.
    insert into public.obligations (
        owner_user_id, company_id, source_type, source_id, kind, due_at,
        severity, title, summary, action_type, fingerprint
    )
    select r.user_id, r.company_id, 'institution', r.source_id, 'new_recurring_charge', now(),
           'attention', 'New recurring charge detected',
           'A newly detected charge appears to recur. Confirm it or add it as a subscription.',
           'review_recurring_charge', 'new_recurring:' || r.account_id || ':' || r.merchant_key
      from (
          select t.user_id, t.company_id, coalesce(t.institution_id, p.institution_id) source_id,
                 coalesce(t.account_id, '') account_id,
                 lower(regexp_replace(coalesce(t.merchant_name, t.name, ''), '[^a-z0-9]', '', 'g')) merchant_key,
                 min(t.date) first_date, max(t.date) last_date, count(*) occurrences,
                 avg(abs(t.amount)) average_amount, stddev_pop(abs(t.amount)) amount_deviation
            from public.plaid_transactions t
            join public.plaid_items p on p.id = t.plaid_item_id
           where t.pending = false and coalesce(t.merchant_name, t.name, '') <> ''
             and (p_user_id is null or t.user_id = p_user_id)
           group by t.user_id, t.company_id, coalesce(t.institution_id, p.institution_id),
                    coalesce(t.account_id, ''), lower(regexp_replace(coalesce(t.merchant_name, t.name, ''), '[^a-z0-9]', '', 'g'))
          having count(*) >= 2
             and max(t.date) - min(t.date) >= 15
             and max(t.date) >= current_date - 7
             and avg(abs(t.amount)) > 0
             and coalesce(stddev_pop(abs(t.amount)) / nullif(avg(abs(t.amount)), 0), 0) < 0.25
      ) r
     where r.source_id is not null
       and not exists (
           select 1 from public.subscriptions s
            where s.user_id = r.user_id
              and lower(regexp_replace(s.name, '[^a-z0-9]', '', 'g')) = r.merchant_key
       )
    on conflict (owner_user_id, fingerprint) do update set updated_at = now();
end;
$$;

-- Plaid Items are the billable unit. The trigger also applies to service-role inserts.
create or replace function public.enforce_miloom_plaid_item_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_limit integer;
begin
    v_limit := case when public.miloom_effective_tier(new.user_id) = 'pro' then 10 else 1 end;
    if new.status = 'active' and (
        select count(*) from public.plaid_items
         where user_id = new.user_id and status = 'active' and id <> new.id
    ) >= v_limit then
        raise exception using errcode = 'P0001', message = 'MILOOM_LIMIT:plaid_items';
    end if;
    return new;
end;
$$;

drop trigger if exists enforce_miloom_plaid_item_limit on public.plaid_items;
create trigger enforce_miloom_plaid_item_limit
before insert or update of status on public.plaid_items
for each row execute function public.enforce_miloom_plaid_item_limit();

-- Limit unique active guest emails across the portfolio, if the external invitation table exists.
create or replace function public.enforce_miloom_guest_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_limit integer; v_count integer; v_exists boolean;
begin
    v_limit := case when public.miloom_effective_tier(new.invited_by) = 'pro' then 3 else 0 end;
    execute 'select exists(select 1 from public.resource_invitations where invited_by = $1 and lower(email) = lower($2) and status in (''Pending'', ''Accepted''))'
       into v_exists using new.invited_by, new.email;
    if v_exists then return new; end if;
    execute 'select count(distinct lower(email)) from public.resource_invitations where invited_by = $1 and status in (''Pending'', ''Accepted'')'
       into v_count using new.invited_by;
    if v_count >= v_limit then
        raise exception using errcode = 'P0001', message = 'MILOOM_LIMIT:guests';
    end if;
    return new;
end;
$$;

do $$
begin
    if to_regclass('public.resource_invitations') is not null then
        execute 'drop trigger if exists enforce_miloom_guest_limit on public.resource_invitations';
        execute 'create trigger enforce_miloom_guest_limit before insert on public.resource_invitations for each row execute function public.enforce_miloom_guest_limit()';
    end if;
end;
$$;

create or replace function public.miloom_resource_owner(p_type text, p_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public
as $$
begin
    return case p_type
        when 'company' then (select user_id from public.companies where id = p_id)
        when 'subscription' then (select user_id from public.subscriptions where id = p_id)
        when 'institution' then (select user_id from public.institutions where id = p_id)
        when 'card' then (select user_id from public.financial_cards where id = p_id)
        when 'loan' then (select user_id from public.loans where id = p_id)
        when 'document' then (select user_id from public.company_documents where id = p_id)
        else null
    end;
end;
$$;

create or replace function public.enforce_miloom_direct_share_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare v_owner uuid; v_limit integer; v_count integer;
begin
    v_owner := public.miloom_resource_owner(new.resource_type, new.resource_id);
    if v_owner is null then return new; end if;
    if exists (
        select 1 from public.resource_shares rs
         where rs.user_id = new.user_id and rs.suspended_at is null
           and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_owner
    ) then return new; end if;
    v_limit := case when public.miloom_effective_tier(v_owner) = 'pro' then 3 else 0 end;
    select count(distinct rs.user_id) into v_count
      from public.resource_shares rs
     where rs.suspended_at is null
       and public.miloom_resource_owner(rs.resource_type, rs.resource_id) = v_owner;
    if v_count >= v_limit then
        raise exception using errcode = 'P0001', message = 'MILOOM_LIMIT:guests';
    end if;
    return new;
end;
$$;

drop trigger if exists enforce_miloom_direct_share_limit on public.resource_shares;
create trigger enforce_miloom_direct_share_limit
before insert on public.resource_shares
for each row execute function public.enforce_miloom_direct_share_limit();

grant execute on function public.refresh_miloom_connections(uuid) to service_role;
grant execute on function public.refresh_miloom_obligations(uuid) to service_role;
grant execute on function public.maintain_miloom_downgrades() to service_role;
