-- Minimal pre-012 vault schema for isolated resource-key foundation tests.
-- Run only in a disposable database after delegated_scope_fixture.sql.
create table public.account_vaults (
    user_id uuid primary key, current_key_version integer not null
);
create table public.vault_devices (
    id uuid primary key, user_id uuid not null, status text not null
);

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

insert into public.account_vaults values ('00000000-0000-0000-0000-000000000001', 1);
insert into public.vault_devices values
    ('70000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'approved'),
    ('70000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000003', 'pending');
