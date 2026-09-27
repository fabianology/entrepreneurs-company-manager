-- Accepting an invitation requires a verified current Auth email, independent
-- of signup/provider settings. Decline and existing grants are unchanged.
begin;
create or replace function public.miloom_act_on_invitation(
    p_invitation_id uuid, p_token text, p_accept boolean
)
returns jsonb language plpgsql security definer set search_path = public, auth as $$
declare
    v_actor uuid := auth.uid();
    v_actor_email text;
    v_email_verified boolean;
    v_invitation public.resource_invitations%rowtype;
begin
    if v_actor is null then raise exception using errcode = '42501', message = 'AUTH_REQUIRED'; end if;
    if (p_invitation_id is null) = (p_token is null) then
        raise exception using errcode = '22023', message = 'INVITATION_REFERENCE_REQUIRED';
    end if;

    -- Hold the identity row stable through grant creation, including concurrent
    -- changes to the current email/confirmation state.
    select lower(u.email), u.email_confirmed_at is not null
        and not coalesce(u.is_anonymous, false)
      into v_actor_email, v_email_verified
      from auth.users u where u.id = v_actor for share;

    select * into v_invitation from public.resource_invitations ri
     where ((p_invitation_id is not null and ri.id = p_invitation_id)
        or (p_token is not null and p_token ~ '^[0-9a-f]{64}$'
            and ri.token_hash = extensions.digest(p_token, 'sha256')))
       and lower(ri.email) = v_actor_email
       and ri.status = 'Pending' and ri.expires_at > now()
     for update;
    if not found then raise exception using errcode = 'P0002', message = 'INVITATION_NOT_AVAILABLE'; end if;
    if exists (select 1 from public.resource_access_blocks b
        where b.owner_user_id = public.miloom_resource_owner(v_invitation.resource_type, v_invitation.resource_id)
          and (lower(b.blocked_email) = v_actor_email or b.blocked_user_id = v_actor)) then
        raise exception using errcode = '42501', message = 'INVITATION_BLOCKED';
    end if;

    if p_accept then
        if v_email_verified is distinct from true then
            raise exception using errcode = '42501', message = 'INVITATION_EMAIL_VERIFICATION_REQUIRED';
        end if;
        insert into public.resource_shares (
            resource_id, resource_type, user_id, role, sender_email, sender_display_name, suspended_at
        ) values (
            v_invitation.resource_id, v_invitation.resource_type, v_actor,
            v_invitation.role, v_invitation.sender_email, null, null
        ) on conflict (resource_id, resource_type, user_id) do update set
            role = excluded.role, sender_email = excluded.sender_email,
            sender_display_name = null, suspended_at = null;
        update public.resource_invitations set status = 'Accepted', accepted_at = now(),
            declined_at = null, token_hash = null, token_issued_at = null
         where id = v_invitation.id;
        return jsonb_build_object('status', 'accepted', 'resource_id', v_invitation.resource_id,
            'resource_type', v_invitation.resource_type);
    end if;
    update public.resource_invitations set status = 'Declined', declined_at = now(),
        accepted_at = null, token_hash = null, token_issued_at = null
     where id = v_invitation.id;
    return jsonb_build_object('status', 'declined');
end;
$$;
-- Keep the existing public accept/decline wrappers; never expose their worker.
revoke all on function public.miloom_act_on_invitation(uuid,text,boolean) from public, anon, authenticated;
notify pgrst, 'reload schema';
commit;
