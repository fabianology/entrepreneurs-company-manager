-- Auth deletion rejects users who still own Storage objects. The deletion
-- handler lists owned files here, then removes them through the Storage API.
-- Never delete storage.objects rows directly: that would leave file bytes behind.
create function public.get_account_deletion_storage_objects(p_user_id uuid)
returns table(bucket_id text, name text)
language sql stable security definer set search_path = '' as $$
  select o.bucket_id, o.name from storage.objects o
  where o.owner_id = p_user_id::text or o.owner = p_user_id
    or (o.bucket_id = 'CompanyDocuments' and o.name like p_user_id::text || '/expense-%')
  order by o.bucket_id, o.name limit 100;
$$;
revoke all on function public.get_account_deletion_storage_objects(uuid) from public, anon, authenticated;
grant execute on function public.get_account_deletion_storage_objects(uuid) to service_role;
