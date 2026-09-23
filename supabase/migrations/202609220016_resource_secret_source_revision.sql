-- A staged ciphertext must correspond to the exact source credential revision
-- that was read by the owner. Metadata edits may conservatively invalidate an
-- institution stage because accounts_data contains both metadata and numbers.
-- This is only a preparation gate; it does not activate any secret or change
-- the legacy owner columns.
begin;

alter table public.subscriptions
    add column secret_revision bigint not null default 0;
alter table public.financial_cards
    add column secret_revision bigint not null default 0;
alter table public.institutions
    add column secret_revision bigint not null default 0;
alter table public.resource_secret_versions
    add column source_secret_revision bigint not null default -1;

create or replace function public.miloom_track_source_secret_revision()
returns trigger
language plpgsql set search_path = ''
as $$
declare
    v_changed boolean;
begin
    if tg_table_name = 'subscriptions' then
        v_changed := row(new.login_id, new.password, new.two_factor_auth, new.recovery_method)
            is distinct from row(old.login_id, old.password, old.two_factor_auth, old.recovery_method);
    elsif tg_table_name = 'financial_cards' then
        v_changed := row(new.login, new.password, new.card_number, new.expiry)
            is distinct from row(old.login, old.password, old.card_number, old.expiry);
    elsif tg_table_name = 'institutions' then
        v_changed := row(new.login_url, new.username, new.email, new.password,
                         new.two_factor, new.accounts_data)
            is distinct from row(old.login_url, old.username, old.email, old.password,
                                 old.two_factor, old.accounts_data);
    else
        raise exception using errcode = '23514', message = 'UNKNOWN_SECRET_SOURCE';
    end if;
    -- Ignore a client-supplied revision, even for an owner or service call.
    new.secret_revision := old.secret_revision + case when v_changed then 1 else 0 end;
    return new;
end;
$$;

-- Trigger names run after the existing shared-record secret guards, so an
-- attempted collaborator change that those guards discard does not advance
-- the revision. Any later credential rewrite still invalidates a stage.
create trigger zz_miloom_track_secret_revision
before update on public.subscriptions
for each row execute function public.miloom_track_source_secret_revision();
create trigger zz_miloom_track_secret_revision
before update on public.financial_cards
for each row execute function public.miloom_track_source_secret_revision();
create trigger zz_miloom_track_secret_revision
before update on public.institutions
for each row execute function public.miloom_track_source_secret_revision();
revoke all on function public.miloom_track_source_secret_revision()
    from public, anon, authenticated;

create or replace function public.miloom_stamp_resource_secret_source_revision()
returns trigger
language plpgsql security definer set search_path = ''
as $$
declare
    v_revision bigint;
begin
    if new.state <> 'staging' then return new; end if;
    if new.resource_type = 'subscription' then
        select s.secret_revision into v_revision from public.subscriptions s
         where s.id = new.resource_id and s.user_id = new.owner_user_id for share;
    elsif new.resource_type = 'card' then
        select c.secret_revision into v_revision from public.financial_cards c
         where c.id = new.resource_id and c.user_id = new.owner_user_id for share;
    elsif new.resource_type = 'institution' then
        select i.secret_revision into v_revision from public.institutions i
         where i.id = new.resource_id and i.user_id = new.owner_user_id for share;
    end if;
    if v_revision is null then
        raise exception using errcode = '23514', message = 'RESOURCE_SECRET_SOURCE_MISSING';
    end if;
    new.source_secret_revision := v_revision;
    return new;
end;
$$;
create trigger stamp_resource_secret_source_revision
before insert or update of encrypted_fields on public.resource_secret_versions
for each row execute function public.miloom_stamp_resource_secret_source_revision();
revoke all on function public.miloom_stamp_resource_secret_source_revision()
    from public, anon, authenticated;

-- The old return type cannot be changed with CREATE OR REPLACE. Keep the same
-- argument contract while adding both revision values for owner verification.
drop function public.miloom_get_owner_resource_secret(text, uuid, uuid, text);
create function public.miloom_get_owner_resource_secret(
    p_resource_type text, p_resource_id uuid,
    p_actor_device_id uuid, p_key_confirmation text
)
returns table (
    resource_type text, resource_id uuid, key_version integer,
    owner_account_key_version integer, owner_wrapped_resource_key text,
    encrypted_fields jsonb, state text,
    source_secret_revision bigint, current_secret_revision bigint
)
language plpgsql security definer set search_path = ''
as $$
begin
    perform public.miloom_require_owner_resource_device(p_actor_device_id, p_key_confirmation);
    if public.miloom_resource_owner(lower(p_resource_type), p_resource_id) is distinct from auth.uid() then
        raise exception using errcode = '42501', message = 'RESOURCE_NOT_OWNED';
    end if;
    return query
    select sv.resource_type, sv.resource_id, sv.key_version,
           sv.owner_account_key_version, sv.owner_wrapped_resource_key,
           sv.encrypted_fields, sv.state, sv.source_secret_revision,
           coalesce(i.secret_revision, c.secret_revision, s.secret_revision)
      from public.resource_secret_versions sv
      left join public.institutions i
        on sv.resource_type = 'institution' and i.id = sv.resource_id
      left join public.financial_cards c
        on sv.resource_type = 'card' and c.id = sv.resource_id
      left join public.subscriptions s
        on sv.resource_type = 'subscription' and s.id = sv.resource_id
     where sv.resource_type = lower(p_resource_type) and sv.resource_id = p_resource_id
       and sv.owner_user_id = auth.uid()
       and sv.state in ('staging', 'active', 'rotation_required')
     order by sv.key_version desc limit 1;
end;
$$;
revoke all on function public.miloom_get_owner_resource_secret(text, uuid, uuid, text)
    from public, anon;
grant execute on function public.miloom_get_owner_resource_secret(text, uuid, uuid, text)
    to authenticated;

notify pgrst, 'reload schema';
commit;
