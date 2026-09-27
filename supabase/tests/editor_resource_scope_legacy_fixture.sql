-- ISOLATED synthetic DB only, after delegated_scope_fixture/current migrations,
-- before 202609270001. Simulates legacy rows without disabling product guards.
insert into public.resource_shares(resource_id,resource_type,user_id,role)
values('10000000-0000-0000-0000-000000000001','company',
       '00000000-0000-0000-0000-000000000003','Editor');
insert into public.resource_invitations(resource_id,resource_type,email,role,invited_by,status)
values('10000000-0000-0000-0000-000000000001','company','legacy-scope@example.com',
       'Editor','00000000-0000-0000-0000-000000000001','Pending');
