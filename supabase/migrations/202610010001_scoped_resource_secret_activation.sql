-- Permit the reviewed, owner/device-bound staged cutover for one resource at a
-- time. This does not grant a collaborator a key: request + owner approval
-- remain separate. Apply only with the compatible native activation build.
begin;

create or replace function public.miloom_resource_secret_user_eligible(
    p_user_id uuid, p_resource_type text, p_resource_id uuid
)
returns boolean
language sql stable security definer set search_path = ''
as $$
    select p_user_id is not null
       and p_user_id is distinct from public.miloom_resource_owner(p_resource_type, p_resource_id)
       and public.miloom_resource_company(p_resource_type, p_resource_id) is not null
       and exists (
           select 1 from auth.users u
            where u.id = p_user_id
              and u.email_confirmed_at is not null
              and not coalesce(u.is_anonymous, false)
       )
       and not exists (
           select 1 from public.resource_access_blocks b
           join auth.users au on au.id = p_user_id
            where b.owner_user_id = public.miloom_resource_owner(p_resource_type, p_resource_id)
              and (b.blocked_user_id = p_user_id or lower(b.blocked_email) = lower(au.email))
       )
       and exists (
           select 1 from public.resource_shares rs
            where rs.user_id = p_user_id
              and rs.suspended_at is null
              and rs.role in ('Editor', 'Admin')
              and (
                  (rs.resource_type = lower(p_resource_type) and rs.resource_id = p_resource_id)
                  or (rs.resource_type = 'company'
                      and rs.resource_id = public.miloom_resource_company(p_resource_type, p_resource_id))
                  or (rs.resource_id = public.miloom_resource_company(p_resource_type, p_resource_id)
                      and (
                          (rs.resource_type = 'all_institutions' and lower(p_resource_type) = 'institution')
                          or (rs.resource_type = 'all_financials' and lower(p_resource_type) in ('institution', 'card'))
                          or (rs.resource_type = 'all_subscriptions' and lower(p_resource_type) = 'subscription')
                      ))
              )
       );
$$;
revoke all on function public.miloom_resource_secret_user_eligible(uuid, text, uuid)
    from public, anon, authenticated;

grant execute on function public.miloom_activate_staged_resource_secret(
    text, uuid, integer, bigint, jsonb, text, uuid, text
) to authenticated;
comment on function public.miloom_activate_staged_resource_secret(
    text, uuid, integer, bigint, jsonb, text, uuid, text
) is 'Owner/device-bound, exact-revision activation of one verified staged resource. Does not grant collaborator keys.';

notify pgrst, 'reload schema';
commit;
