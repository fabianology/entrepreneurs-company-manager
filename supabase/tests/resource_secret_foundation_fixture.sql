-- Minimal pre-012 vault schema for isolated resource-key foundation tests.
-- Run only in a disposable database after delegated_scope_fixture.sql.
alter table public.subscriptions
    add column login_id text, add column password text,
    add column two_factor_auth text, add column recovery_method text;
alter table public.financial_cards
    add column login text, add column password text,
    add column card_number text, add column expiry text;
alter table public.institutions
    add column login_url text, add column username text, add column email text,
    add column password text, add column two_factor text,
    add column accounts_data jsonb not null default '[]'::jsonb;
create table public.account_vaults (
    user_id uuid primary key, current_key_version integer not null,
    key_confirmation text not null, rotation_status text not null default 'stable'
);
create table public.vault_devices (
    id uuid primary key, user_id uuid not null, status text not null,
    auth_session_id uuid, label text not null, agreement_public_key text not null
);

create function auth.jwt() returns jsonb language sql stable as $$
    select jsonb_build_object(
        'session_id', current_setting('request.jwt.claim.session_id', true),
        'iat', current_setting('request.jwt.claim.iat', true)
    )
$$;
create function public.miloom_require_recent_access_token()
returns void language plpgsql stable as $$
begin
    if auth.uid() is null or nullif(current_setting('request.jwt.claim.iat', true), '') is null
       or to_timestamp(current_setting('request.jwt.claim.iat', true)::double precision)
            < now() - interval '10 minutes' then
        raise exception using errcode = '42501', message = 'RECENT_ACCESS_TOKEN_REQUIRED';
    end if;
end;
$$;

create function public.miloom_is_base64_octets(p_value text, p_octets integer)
returns boolean language plpgsql immutable strict as $$
begin
    return octet_length(decode(p_value, 'base64')) = p_octets;
exception when others then return false;
end;
$$;
create function public.miloom_is_p256_public_key(p_value text)
returns boolean language plpgsql immutable strict as $$
begin
    return octet_length(decode(p_value, 'base64')) = 65
        and get_byte(decode(p_value, 'base64'), 0) = 4;
exception when others then return false;
end;
$$;

insert into public.account_vaults (user_id, current_key_version, key_confirmation)
values ('00000000-0000-0000-0000-000000000001', 1,
        encode(convert_to(repeat('k', 32), 'utf8'), 'base64'));
insert into public.vault_devices values
    ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'approved',
        '80000000-0000-0000-0000-000000000002', 'Editor iPhone',
        encode(decode('04' || repeat('11', 64), 'hex'), 'base64')),
    ('70000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'pending',
        null, 'Viewer iPhone', encode(decode('04' || repeat('22', 64), 'hex'), 'base64')),
    ('70000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'approved',
        '80000000-0000-0000-0000-000000000001', 'Owner iPhone',
        encode(decode('04' || repeat('33', 64), 'hex'), 'base64'));
