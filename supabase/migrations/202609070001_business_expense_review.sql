-- Business review is separate from the financial ledger. Only owner-scoped RPCs
-- may write; AI has no permission to confirm business use.
create table public.business_expense_settings (
  user_id uuid primary key references auth.users(id) on delete cascade,
  enabled boolean not null default false,
  consent_version text,
  consented_at timestamptz,
  excluded_account_ids text[] not null default '{}',
  learning_reset_at timestamptz not null default '-infinity',
  revision integer not null default 1,
  updated_at timestamptz not null default now()
);
create table public.business_expense_profiles (
  company_id uuid primary key references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  activity text not null default '',
  enabled boolean not null default true
);
create table public.business_expense_reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  transaction_id uuid unique references public.plaid_transactions(id) on delete set null,
  origin text not null default 'manual' check(origin in ('manual','ai')),
  decision text not null default 'unreviewed' check (decision in ('unreviewed','confirmed','personal','dismissed')),
  source_state text not null default 'active' check (source_state in ('active','changed','removed','disconnected','conflict')),
  source_snapshot jsonb not null,
  revision integer not null default 1,
  confirmed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.business_expense_source_links (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  review_id uuid not null references public.business_expense_reviews(id) on delete cascade,
  transaction_id uuid unique references public.plaid_transactions(id) on delete set null,
  provider_transaction_id text not null,
  source_account_id text not null,
  unique(user_id,provider_transaction_id)
);
create table public.business_expense_allocations (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null unique references public.business_expense_reviews(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  business_basis_points integer not null check (business_basis_points between 1 and 10000),
  purpose text not null default '',
  category text not null default '',
  receipt_exception text not null default '',
  context text not null default '',
  notes text not null default '',
  treatment text not null default 'undetermined' check (treatment in ('undetermined','owner_paid','reimbursement','contribution','other')),
  professional_status text not null default 'not_requested' check (professional_status in ('not_requested','requested','owner_recorded_review'))
);
create table public.business_expense_suggestions (
  id uuid primary key default gen_random_uuid(),
  review_id uuid not null references public.business_expense_reviews(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  state text not null default 'active' check (state in ('active','accepted','rejected','superseded')),
  score numeric not null check (score between 0 and 1),
  confidence text not null check (confidence in ('worth_reviewing','high')),
  explanation text not null,
  evidence_ids uuid[] not null default '{}',
  input_fingerprint text not null,
  model_version text not null,
  policy_version text not null default 'business-review-v1',
  created_at timestamptz not null default now(),
  unique(review_id,company_id)
);
create table public.business_expense_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  review_id uuid not null references public.business_expense_reviews(id) on delete cascade,
  action text not null,
  actor text not null check (actor in ('owner','source','ai')),
  revision integer not null,
  details jsonb not null default '{}',
  mutation_id uuid,
  created_at timestamptz not null default now(),
  unique(user_id,mutation_id)
);
alter table public.company_documents add column if not exists visibility text not null default 'entity'
  check (visibility in ('entity','owner_private'));
-- Restrictive policies AND with existing grants, preventing a permissive legacy
-- Entity-sharing policy from revealing private receipt metadata.
create policy business_receipts_private on public.company_documents as restrictive for all to authenticated
  using (visibility <> 'owner_private' or user_id = auth.uid())
  with check (visibility <> 'owner_private' or user_id = auth.uid());
create table public.business_expense_documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  review_id uuid not null references public.business_expense_reviews(id) on delete cascade,
  document_id uuid not null references public.company_documents(id) on delete cascade,
  unique(review_id,document_id)
);
create table public.business_expense_exports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  mutation_id uuid not null,
  format_version text not null default 'miloom-expenses-csv-v1',
  incomplete boolean not null default false,
  items jsonb not null,
  created_at timestamptz not null default now(),
  unique(user_id,mutation_id)
);
create table public.business_expense_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date_from date not null,
  date_to date not null,
  state text not null default 'queued' check(state in ('queued','running','complete','paused','failed','cancelled')),
  consent_revision integer not null,
  cursor_date date,
  cursor_id uuid,
  scanned integer not null default 0,
  suggested integer not null default 0,
  error_code text,
  lease_token uuid,
  lease_until timestamptz,
  attempts integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(date_from <= date_to)
);
create unique index business_expense_one_active_job on public.business_expense_jobs(user_id)
  where state in ('queued','running');
create table public.business_expense_screened_inputs (
  user_id uuid not null references auth.users(id) on delete cascade,
  transaction_id uuid not null references public.plaid_transactions(id) on delete cascade,
  fingerprint text not null,
  screened_at timestamptz not null default now(),
  primary key(user_id,transaction_id)
);
create table public.business_expense_usage_reservations (
  user_id uuid not null references auth.users(id) on delete cascade,
  batch_id text not null,
  created_at timestamptz not null default now(),
  primary key(user_id,batch_id)
);
create index business_expense_reviews_owner on public.business_expense_reviews(user_id,updated_at desc);
create index business_expense_allocations_company on public.business_expense_allocations(user_id,company_id);
create index business_expense_jobs_queue on public.business_expense_jobs(state,lease_until);

do $$ declare n text; begin
  foreach n in array array['settings','profiles','reviews','source_links','allocations','suggestions','events','documents','exports','jobs','screened_inputs','usage_reservations'] loop
    execute format('alter table public.business_expense_%I enable row level security',n);
    execute format('create policy owner_read on public.business_expense_%I for select to authenticated using(user_id = auth.uid())',n);
    execute format('revoke all on public.business_expense_%I from anon, authenticated',n);
    execute format('grant select on public.business_expense_%I to authenticated',n);
    execute format('grant all on public.business_expense_%I to service_role',n);
  end loop;
end $$;

create function public.business_expense_snapshot(p_transaction_id uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
 select jsonb_build_object(
   'merchant',coalesce(nullif(o.merchant_name,''),t.merchant_name,t.name,'Unknown transaction'),
   'date',t.date,'amount',abs(t.amount::numeric),'currency',t.currency,
   'persistent_account_id',a.persistent_account_id,
   'source_account_id',t.account_id,'canonical_account_id',coalesce(t.canonical_account_id,t.account_id),
   'source_company_id',coalesce(a.company_id,i.company_id),
   'account_name',coalesce(a.name,c.name,'Connected account'),
   'institution_name',coalesce(i.name,c.institution_name,'Connected institution'))
 from public.plaid_transactions t
 left join public.plaid_transaction_overrides o on o.transaction_id=t.id and o.user_id=t.user_id
 left join lateral (select pa.* from public.plaid_accounts pa where pa.user_id=t.user_id and pa.account_id=t.account_id order by pa.last_seen_at desc limit 1) a on true
 left join public.institutions i on i.id=coalesce(a.institution_id,t.institution_id)
 left join lateral (select fc.* from public.financial_cards fc where fc.user_id=t.user_id and fc.plaid_account_id=coalesce(t.canonical_account_id,t.account_id) limit 1) c on true
 where t.id=p_transaction_id;
$$;
create function public.ensure_business_expense_review(p_user_id uuid,p_transaction_id uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare t public.plaid_transactions; rid uuid; existing public.business_expense_reviews; begin
 select * into t from public.plaid_transactions where id=p_transaction_id and user_id=p_user_id for update;
 if not found then raise exception 'EXPENSE_SOURCE_NOT_FOUND'; end if;
 select review_id into rid from public.business_expense_source_links where user_id=p_user_id and provider_transaction_id=t.plaid_transaction_id;
 if rid is not null then
   update public.business_expense_source_links set transaction_id=t.id where review_id=rid and provider_transaction_id=t.plaid_transaction_id;
   update public.business_expense_reviews set transaction_id=t.id,source_state=case when decision='confirmed' then 'changed' else 'active' end,
     revision=revision+1,updated_at=now() where id=rid and transaction_id is null and source_state<>'conflict';
   return rid;
 end if;
 if t.is_superseded_duplicate or t.is_stale_pending_duplicate then raise exception 'EXPENSE_SOURCE_SUPERSEDED'; end if;
 insert into public.business_expense_reviews(user_id,transaction_id,source_snapshot)
 values(p_user_id,t.id,public.business_expense_snapshot(t.id)) on conflict(transaction_id) do nothing;
 select id into rid from public.business_expense_reviews where transaction_id=t.id;
 insert into public.business_expense_source_links(user_id,review_id,transaction_id,provider_transaction_id,source_account_id)
 values(p_user_id,rid,t.id,t.plaid_transaction_id,t.account_id) on conflict do nothing;
 return rid;
end $$;
create function public.business_expense_missing(p_review_id uuid) returns text[]
language plpgsql stable security definer set search_path = '' as $$
declare r public.business_expense_reviews; a public.business_expense_allocations; missing text[] := '{}'; begin
 select * into r from public.business_expense_reviews where id=p_review_id;
 select * into a from public.business_expense_allocations where review_id=p_review_id;
 if r.decision <> 'confirmed' then missing := array_append(missing,'Business confirmation'); end if;
 if a.id is null then missing := array_append(missing,'Entity and business-use percentage'); end if;
 if coalesce(trim(a.purpose),'')='' then missing := array_append(missing,'Business purpose'); end if;
 if coalesce(trim(a.category),'')='' then missing := array_append(missing,'Expense category'); end if;
 if not exists(select 1 from public.business_expense_documents ed join public.company_documents d on d.id=ed.document_id
   join storage.objects so on so.bucket_id='CompanyDocuments' and so.name=d.url
   where ed.review_id=p_review_id and d.user_id=r.user_id and d.visibility='owner_private')
   and coalesce(trim(a.receipt_exception),'')='' then missing := array_append(missing,'Receipt or missing-receipt explanation'); end if;
 if r.transaction_id is not null and not coalesce(public.business_expense_source_eligible(r.transaction_id),false) then missing := array_append(missing,'Source is no longer an eligible expense'); end if;
 if r.source_state not in ('active','disconnected') then missing := array_append(missing,'Source needs attention'); end if;
 if (r.source_snapshot->>'amount') is null or (r.source_snapshot->>'currency') is null then missing := array_append(missing,'Source amount or currency'); end if;
 return missing;
end $$;
create function public.get_business_expense_reviews() returns jsonb
language sql stable security definer set search_path = '' as $$
 select coalesce(jsonb_agg(jsonb_build_object(
 'id',r.id,'transaction_id',r.transaction_id,'decision',r.decision,'origin',r.origin,'source_state',r.source_state,
 'source',r.source_snapshot,'revision',r.revision,'updated_at',r.updated_at,
 'allocation',(select to_jsonb(a) from public.business_expense_allocations a where a.review_id=r.id),
 'suggestions',coalesce((select jsonb_agg(to_jsonb(s) order by s.score desc) from public.business_expense_suggestions s where s.review_id=r.id and s.state='active'),'[]'),
 'documents',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'path',d.url)) from public.business_expense_documents ed join public.company_documents d on d.id=ed.document_id where ed.review_id=r.id),'[]'),
 'missing',public.business_expense_missing(r.id),
 'exported_revision',(select max((item->>'revision')::int) from public.business_expense_exports e cross join lateral jsonb_array_elements(e.items) item where e.user_id=r.user_id and item->>'review_id'=r.id::text)
 ) order by r.updated_at desc),'[]') from public.business_expense_reviews r where r.user_id=auth.uid();
$$;
create function public.configure_business_expenses(p_enabled boolean,p_excluded_accounts text[],p_profiles jsonb,p_expected_revision integer default 0,p_reset_learning boolean default false) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := auth.uid(); s public.business_expense_settings; profile jsonb; cid uuid; begin
 if uid is null then raise exception 'Unauthorized'; end if;
 insert into public.business_expense_settings(user_id) values(uid) on conflict do nothing;
 select * into s from public.business_expense_settings where user_id=uid for update;
 if p_expected_revision<>0 and s.revision<>p_expected_revision then raise exception 'EXPENSE_REVISION_CONFLICT'; end if;
 if jsonb_typeof(p_profiles)<>'array' or jsonb_array_length(p_profiles)>100 then raise exception 'Invalid Entity profiles'; end if;
 for profile in select * from jsonb_array_elements(p_profiles) loop
   cid := (profile->>'company_id')::uuid;
   if not exists(select 1 from public.companies where id=cid and user_id=uid) then raise exception 'Entity not owned'; end if;
   insert into public.business_expense_profiles(company_id,user_id,activity,enabled)
   values(cid,uid,left(coalesce(profile->>'activity',''),1000),coalesce((profile->>'enabled')::boolean,true))
   on conflict(company_id) do update set activity=excluded.activity,enabled=excluded.enabled;
 end loop;
 update public.business_expense_settings set enabled=p_enabled,excluded_account_ids=array(select distinct v from unnest(coalesce(p_excluded_accounts,'{}')||array(select 'persistent:'||pa.persistent_account_id from public.plaid_accounts pa where pa.user_id=uid and pa.persistent_account_id is not null and(pa.account_id=any(p_excluded_accounts) or pa.canonical_account_id=any(p_excluded_accounts)))) v),
   consent_version=case when p_enabled then 'feature-all-owned-accounts-v1' else consent_version end,
   consented_at=case when p_enabled and not s.enabled then now() else consented_at end,
   learning_reset_at=case when p_reset_learning then now() else learning_reset_at end,
   revision=revision+1,updated_at=now() where user_id=uid returning * into s;
 update public.business_expense_jobs set state='cancelled',lease_token=null,lease_until=null where user_id=uid and state in ('queued','running','paused');
 return to_jsonb(s);
end $$;
create function public.save_business_expense(p_transaction_id uuid,p_review_id uuid,p_expected_revision integer,p_mutation_id uuid,p_decision text,p_allocation jsonb,p_acknowledge_source boolean default false) returns uuid
language plpgsql security definer set search_path = '' as $$
declare uid uuid:=auth.uid(); rid uuid; r public.business_expense_reviews; cid uuid; t public.plaid_transactions; flow text; begin
 if uid is null then raise exception 'Unauthorized'; end if;
 select review_id into rid from public.business_expense_events where user_id=uid and mutation_id=p_mutation_id;
 if rid is not null then return rid; end if;
 rid:=p_review_id;
 if rid is null then rid:=public.ensure_business_expense_review(uid,p_transaction_id); end if;
 select * into r from public.business_expense_reviews where id=rid and user_id=uid for update;
 if not found then raise exception 'Review not owned'; end if;
 if r.revision<>p_expected_revision then raise exception 'EXPENSE_REVISION_CONFLICT'; end if;
 if p_decision not in ('unreviewed','confirmed','personal','dismissed') then raise exception 'Invalid decision'; end if;
 if p_decision='confirmed' then
   cid:=(p_allocation->>'company_id')::uuid;
   if not exists(select 1 from public.companies where id=cid and user_id=uid) then raise exception 'Entity not owned'; end if;
   if r.transaction_id is not null then
     select * into t from public.plaid_transactions where id=r.transaction_id;
     select flow_override into flow from public.plaid_transaction_overrides where transaction_id=t.id and user_id=uid;
     if not coalesce(public.business_expense_source_eligible(t.id),false) or t.pending or t.is_superseded_duplicate or t.is_stale_pending_duplicate or t.amount is null or t.amount=0
       or coalesce(flow,'expense') in ('income','refund','transfer','ignored') or (t.amount<0 and flow is distinct from 'expense') then raise exception 'Only posted expense transactions can be confirmed'; end if;
   elsif r.source_state<>'disconnected' then raise exception 'Source unavailable'; end if;
   insert into public.business_expense_allocations(review_id,user_id,company_id,business_basis_points,purpose,category,receipt_exception,context,notes,treatment,professional_status)
   values(rid,uid,cid,(p_allocation->>'business_basis_points')::int,coalesce(p_allocation->>'purpose',''),coalesce(p_allocation->>'category',''),coalesce(p_allocation->>'receipt_exception',''),coalesce(p_allocation->>'context',''),coalesce(p_allocation->>'notes',''),coalesce(p_allocation->>'treatment','undetermined'),coalesce(p_allocation->>'professional_status','not_requested'))
   on conflict(review_id) do update set company_id=excluded.company_id,business_basis_points=excluded.business_basis_points,purpose=excluded.purpose,category=excluded.category,receipt_exception=excluded.receipt_exception,context=excluded.context,notes=excluded.notes,treatment=excluded.treatment,professional_status=excluded.professional_status;
   update public.company_documents d set company_id=cid where d.user_id=uid and d.visibility='owner_private' and d.id in(select document_id from public.business_expense_documents where review_id=rid);
 else
   delete from public.business_expense_allocations where review_id=rid;
 end if;
 update public.business_expense_reviews set decision=p_decision,origin='manual',revision=revision+1,updated_at=now(),
   confirmed_at=case when p_decision='confirmed' then now() else null end,
   source_snapshot=case when p_acknowledge_source and transaction_id is not null and source_state='changed' then public.business_expense_snapshot(transaction_id) else source_snapshot end,
   source_state=case when p_acknowledge_source and transaction_id is not null and source_state='changed' then 'active' else source_state end
 where id=rid returning * into r;
 update public.business_expense_suggestions set state=case when p_decision='confirmed' and company_id=cid then 'accepted' when p_decision='unreviewed' then 'active' else 'rejected' end where review_id=rid;
 insert into public.business_expense_events(user_id,review_id,action,actor,revision,details,mutation_id)
 values(uid,rid,'review_saved','owner',r.revision,jsonb_build_object('decision',p_decision,'allocation',p_allocation),p_mutation_id);
 perform public.refresh_business_expense_briefing(uid);
 return rid;
end $$;

-- Preserve evidence when Plaid removes a row. Follow an explicit posted or
-- supersession link, never a new fuzzy merchant/date/amount match.
create function public.track_business_expense_source() returns trigger
language plpgsql security definer set search_path = '' as $$
declare rid uuid; replacement uuid; other uuid; next_tx public.plaid_transactions; changed boolean; begin
 if tg_op='UPDATE' and row(old.amount,old.date,old.currency,old.account_id,old.pending,old.superseded_by_transaction_id,old.posted_transaction_id) is not distinct from row(new.amount,new.date,new.currency,new.account_id,new.pending,new.superseded_by_transaction_id,new.posted_transaction_id) then return new; end if;
 select review_id into rid from public.business_expense_source_links where transaction_id=old.id;
 if rid is null or exists(select 1 from public.business_expense_reviews where id=rid and transaction_id is distinct from old.id) then if tg_op='DELETE' then return old; else return new; end if; end if;
 if tg_op='UPDATE' then replacement:=coalesce(new.superseded_by_transaction_id,new.posted_transaction_id);
 else
   select id into replacement from public.plaid_transactions where user_id=old.user_id and pending_transaction_id=old.plaid_transaction_id and not pending and id<>old.id limit 1;
 end if;
 if replacement is not null then
   select review_id into other from public.business_expense_source_links where transaction_id=replacement;
   if other is not null and other<>rid then
     update public.business_expense_reviews set source_state='conflict',revision=revision+1,updated_at=now() where id in(rid,other);
   else
     select * into next_tx from public.plaid_transactions where id=replacement and user_id=old.user_id;
     if found then
       insert into public.business_expense_source_links(user_id,review_id,transaction_id,provider_transaction_id,source_account_id)
       values(old.user_id,rid,replacement,next_tx.plaid_transaction_id,next_tx.account_id) on conflict do nothing;
       update public.business_expense_reviews set transaction_id=replacement,
         source_state=case when decision='confirmed' and (source_snapshot->>'amount')::numeric is distinct from abs(next_tx.amount::numeric) then 'changed' else 'active' end,
         revision=revision+1,updated_at=now() where id=rid;
     end if;
   end if;
 elsif tg_op='DELETE' then
   update public.business_expense_reviews set source_state=case when source_state in('disconnected','changed','conflict') then source_state else 'removed' end,revision=revision+1,updated_at=now() where id=rid;
 elsif row(old.amount,old.date,old.currency,old.account_id) is distinct from row(new.amount,new.date,new.currency,new.account_id) then
   update public.business_expense_reviews set source_state='changed',revision=revision+1,updated_at=now() where id=rid;
 end if;
 insert into public.business_expense_events(user_id,review_id,action,actor,revision,details)
 select user_id,id,'source_'||lower(tg_op),'source',revision,jsonb_build_object('replacement_id',replacement) from public.business_expense_reviews where id=rid;
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
create trigger business_expense_source_changes before update or delete on public.plaid_transactions
 for each row execute function public.track_business_expense_source();
create function public.detach_business_expense_bank() returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.business_expense_reviews r set source_state=case when source_state='active' then 'disconnected' else source_state end,revision=revision+1,updated_at=now()
 where r.user_id=old.user_id and r.transaction_id in(select id from public.plaid_transactions where plaid_item_id=old.id);
 update public.business_expense_jobs set state='cancelled',lease_token=null,lease_until=null where user_id=old.user_id and state in ('queued','running','paused');
 return old;
end $$;
create trigger business_expense_bank_removal before delete on public.plaid_items for each row execute function public.detach_business_expense_bank();

create function public.attach_business_expense_document(p_review_id uuid,p_name text,p_path text,p_expected_revision integer) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); r public.business_expense_reviews; cid uuid; did uuid; begin
 select * into r from public.business_expense_reviews where id=p_review_id and user_id=uid for update;
 if not found then raise exception 'Review not owned'; end if;
 if r.revision<>p_expected_revision then raise exception 'EXPENSE_REVISION_CONFLICT'; end if;
 select company_id into cid from public.business_expense_allocations where review_id=r.id;
 if cid is null then raise exception 'Confirm an Entity before attaching evidence'; end if;
 if split_part(p_path,'/',1)<>uid::text or not exists(select 1 from storage.objects where bucket_id='CompanyDocuments' and name=p_path) then raise exception 'Uploaded receipt not found'; end if;
 insert into public.company_documents(user_id,company_id,name,type,url,visibility) values(uid,cid,left(p_name,200),'Receipts',p_path,'owner_private') returning id into did;
 insert into public.business_expense_documents(user_id,review_id,document_id) values(uid,r.id,did);
 update public.business_expense_reviews set revision=revision+1,updated_at=now() where id=r.id;
 insert into public.business_expense_events(user_id,review_id,action,actor,revision,details) values(uid,r.id,'receipt_attached','owner',r.revision+1,jsonb_build_object('document_id',did));
 return did;
end $$;
create function public.detach_business_expense_document(p_review_id uuid,p_document_id uuid,p_expected_revision integer) returns void
language plpgsql security definer set search_path='' as $$
declare r public.business_expense_reviews; begin
 select * into r from public.business_expense_reviews where id=p_review_id and user_id=auth.uid() for update;
 if not found then raise exception 'Review not owned'; end if;
 if r.revision<>p_expected_revision then raise exception 'EXPENSE_REVISION_CONFLICT'; end if;
 delete from public.business_expense_documents where review_id=r.id and document_id=p_document_id;
 update public.business_expense_reviews set revision=revision+1,updated_at=now() where id=r.id;
 insert into public.business_expense_events(user_id,review_id,action,actor,revision,details) values(r.user_id,r.id,'receipt_unlinked','owner',r.revision+1,jsonb_build_object('document_id',p_document_id));
end $$;
create function public.prepare_business_expense_export(p_company_id uuid,p_date_from date,p_date_to date,p_incomplete boolean,p_mutation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); eid uuid; payload jsonb; begin
 if not exists(select 1 from public.companies where id=p_company_id and user_id=uid) then raise exception 'Entity not owned'; end if;
 select id into eid from public.business_expense_exports where user_id=uid and mutation_id=p_mutation_id;
 if eid is not null then return(select to_jsonb(e) from public.business_expense_exports e where id=eid); end if;
 -- Lock records until the exact export revisions have been captured.
 perform r.id from public.business_expense_reviews r join public.business_expense_allocations a on a.review_id=r.id
 where r.user_id=uid and a.company_id=p_company_id order by r.id for update of r;
 select jsonb_agg(jsonb_build_object('review_id',r.id,'revision',r.revision,'source',r.source_snapshot,
 'allocation',to_jsonb(a),'entity_name',c.name,'source_state',r.source_state,'decision',r.decision,
 'missing',public.business_expense_missing(r.id),'documents',coalesce((select jsonb_agg(jsonb_build_object('id',d.id,'name',d.name,'path',d.url)) from public.business_expense_documents ed join public.company_documents d on d.id=ed.document_id where ed.review_id=r.id),'[]')) order by r.source_snapshot->>'date',r.id)
 into payload from public.business_expense_reviews r join public.business_expense_allocations a on a.review_id=r.id join public.companies c on c.id=a.company_id
 where r.user_id=uid and a.company_id=p_company_id and r.decision='confirmed'
 and (r.source_snapshot->>'date')::date between p_date_from and p_date_to;
 if payload is null then raise exception 'No confirmed expenses in this date range'; end if;
 if not p_incomplete and exists(select 1 from jsonb_array_elements(payload) x where jsonb_array_length(x->'missing')>0) then raise exception 'EXPENSE_EXPORT_INCOMPLETE'; end if;
 insert into public.business_expense_exports(user_id,company_id,mutation_id,incomplete,items) values(uid,p_company_id,p_mutation_id,p_incomplete,payload) returning id into eid;
 return(select to_jsonb(e) from public.business_expense_exports e where id=eid);
end $$;
create function public.start_business_expense_scan(p_date_from date,p_date_to date) returns uuid
language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); s public.business_expense_settings; jid uuid; begin
 select * into s from public.business_expense_settings where user_id=uid for update;
 if not found or not s.enabled then raise exception 'Enable screening first'; end if;
 if not exists(select 1 from public.user_entitlements where user_id=uid and tier='pro' and
 (status='active' or (status='trial' and trial_ends_at>now()) or (status='grace' and grace_ends_at>now()))) then raise exception 'EXPENSE_PRO_REQUIRED'; end if;
 if p_date_to<p_date_from or p_date_to>current_date then raise exception 'Invalid date range'; end if;
 select id into jid from public.business_expense_jobs where user_id=uid and state in ('queued','running');
 if jid is not null then return jid; end if;
 insert into public.business_expense_jobs(user_id,date_from,date_to,consent_revision) values(uid,p_date_from,p_date_to,s.revision) returning id into jid;
 return jid;
end $$;
create function public.claim_business_expense_job(p_job_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare j public.business_expense_jobs; begin
 update public.business_expense_jobs set state='running',lease_token=gen_random_uuid(),lease_until=now()+interval '3 minutes',attempts=attempts+1
 where id=p_job_id and state in('queued','running') and (lease_until is null or lease_until<now()) returning * into j;
 return to_jsonb(j);
end $$;
create function public.reserve_business_expense_usage(p_user_id uuid,p_batch_id text) returns boolean
language plpgsql security definer set search_path='' as $$
declare used integer; begin
 perform 1 from public.business_expense_settings where user_id=p_user_id and enabled for update;
 if not found then return false; end if;
 if exists(select 1 from public.business_expense_usage_reservations where user_id=p_user_id and batch_id=p_batch_id) then return true; end if;
 if not exists(select 1 from public.user_entitlements where user_id=p_user_id and tier='pro' and
 (status='active' or(status='trial' and trial_ends_at>now())or(status='grace' and grace_ends_at>now()))) then return false; end if;
 insert into public.usage_buckets(user_id,period_start) values(p_user_id,date_trunc('month',now())::date) on conflict do nothing;
 select ai_actions into used from public.usage_buckets where user_id=p_user_id and period_start=date_trunc('month',now())::date for update;
 if used>=300 then return false; end if;
 update public.usage_buckets set ai_actions=ai_actions+1,updated_at=now() where user_id=p_user_id and period_start=date_trunc('month',now())::date;
 insert into public.business_expense_usage_reservations(user_id,batch_id) values(p_user_id,p_batch_id);
 return true;
end $$;
-- Refresh only this feature's obligations; the existing reminder lifecycle stays intact.
alter table public.obligations add column if not exists tax_review_candidate_ids uuid[];
create function public.refresh_business_expense_briefing(p_user_id uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 insert into public.obligations(owner_user_id,company_id,source_type,source_id,kind,severity,title,summary,action_type,fingerprint,tax_review_candidate_ids)
 select p_user_id,s.company_id,'company',s.company_id,'business_expense_review','info',c.name||' · Tax Opportunities',
 count(distinct r.id)||' potential business expenses worth reviewing','open_tax_opportunities','tax-review:'||s.company_id,array_agg(distinct r.id)
 from public.business_expense_suggestions s join public.business_expense_reviews r on r.id=s.review_id join public.companies c on c.id=s.company_id
 where s.user_id=p_user_id and s.state='active' and r.decision='unreviewed' and r.source_state='active'
 group by s.company_id,c.name
 on conflict(owner_user_id,fingerprint) do update set summary=excluded.summary,updated_at=now(),
 state=case when public.obligations.state<>'snoozed' and not excluded.tax_review_candidate_ids <@ coalesce(public.obligations.tax_review_candidate_ids,'{}') then 'open' else public.obligations.state end,
 tax_review_candidate_ids=excluded.tax_review_candidate_ids;
 update public.obligations o set state='handled',updated_at=now() where o.owner_user_id=p_user_id and o.kind='business_expense_review'
 and not exists(select 1 from public.business_expense_suggestions s join public.business_expense_reviews r on r.id=s.review_id where s.company_id=o.company_id and s.user_id=p_user_id and s.state='active' and r.decision='unreviewed' and r.source_state='active');
end $$;

-- Deny direct sharing of private evidence even through definer sharing RPCs.
create function public.reject_private_expense_share() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.resource_type='document' and exists(select 1 from public.company_documents where id=new.resource_id and visibility='owner_private') then raise exception 'Private business receipts cannot be shared. Use an accountant export.'; end if;
 return new;
end $$;
create trigger private_expense_share_guard before insert or update on public.resource_shares for each row execute function public.reject_private_expense_share();
create trigger private_expense_invitation_guard before insert or update on public.resource_invitations for each row execute function public.reject_private_expense_share();

-- Functions default to service-only. Only narrow owner RPCs are exposed.
do $$ declare f record; begin
 for f in select oid::regprocedure signature from pg_proc where pronamespace='public'::regnamespace and
 (proname like '%business_expense%' or proname='reject_private_expense_share') loop
   execute format('revoke all on function %s from public,anon,authenticated',f.signature);
   execute format('grant execute on function %s to service_role',f.signature);
 end loop;
end $$;
grant execute on function public.get_business_expense_reviews(),public.configure_business_expenses(boolean,text[],jsonb,integer,boolean),
 public.save_business_expense(uuid,uuid,integer,uuid,text,jsonb,boolean),public.attach_business_expense_document(uuid,text,text,integer),
 public.detach_business_expense_document(uuid,uuid,integer),public.prepare_business_expense_export(uuid,date,date,boolean,uuid),
 public.start_business_expense_scan(date,date) to authenticated;

-- Commit an AI batch only while its lease and consent revision still hold. The
-- result, screened fingerprint and cursor commit together, making retries safe.
create function public.commit_business_expense_batch(p_job_id uuid,p_lease_token uuid,p_results jsonb,p_cursor_date date,p_cursor_id uuid,p_scanned integer,p_complete boolean) returns void
language plpgsql security definer set search_path='' as $$
declare j public.business_expense_jobs; s public.business_expense_settings; result jsonb; candidate jsonb; rid uuid; cid uuid; count_new integer:=0; begin
 select * into j from public.business_expense_jobs where id=p_job_id for update;
 select * into s from public.business_expense_settings where user_id=j.user_id for update;
 if not found or not s.enabled or s.revision<>j.consent_revision or j.state<>'running' or j.lease_token is distinct from p_lease_token or j.lease_until<now() then raise exception 'EXPENSE_STALE_JOB'; end if;
 for result in select * from jsonb_array_elements(p_results) loop
   if not exists(select 1 from public.plaid_transactions t where t.id=(result->>'transaction_id')::uuid and t.user_id=j.user_id
      and not t.pending and not t.is_superseded_duplicate and not t.is_stale_pending_duplicate
      and not public.business_expense_account_excluded(j.user_id,t.account_id,coalesce(t.canonical_account_id,t.account_id))) then continue; end if;
   if public.business_expense_input_version((result->>'transaction_id')::uuid) is distinct from result->>'input_version' then continue; end if;
   if jsonb_array_length(result->'candidates')>0 then
     rid:=public.ensure_business_expense_review(j.user_id,(result->>'transaction_id')::uuid);
     update public.business_expense_reviews set origin='ai' where id=rid and not exists(select 1 from public.business_expense_events where review_id=rid and actor='owner');
     perform 1 from public.business_expense_reviews where id=rid and decision='unreviewed' and source_state='active' for update;
     if found then
       update public.business_expense_suggestions set state='superseded' where review_id=rid and state='active';
       for candidate in select * from jsonb_array_elements(result->'candidates') loop
         cid:=(candidate->>'company_id')::uuid;
         if not exists(select 1 from public.business_expense_profiles where user_id=j.user_id and company_id=cid and enabled) then continue; end if;
         insert into public.business_expense_suggestions(review_id,user_id,company_id,score,confidence,explanation,evidence_ids,input_fingerprint,model_version)
         values(rid,j.user_id,cid,(candidate->>'score')::numeric,candidate->>'confidence',candidate->>'explanation',
           array(select jsonb_array_elements_text(candidate->'evidence_ids')::uuid),result->>'fingerprint',result->>'model')
         on conflict(review_id,company_id) do update set state='active',score=excluded.score,confidence=excluded.confidence,explanation=excluded.explanation,evidence_ids=excluded.evidence_ids,input_fingerprint=excluded.input_fingerprint,model_version=excluded.model_version;
       end loop;
       count_new:=count_new+1;
       insert into public.business_expense_events(user_id,review_id,action,actor,revision,details)
       select user_id,id,'suggestion_generated','ai',revision,jsonb_build_object('fingerprint',result->>'fingerprint','model',result->>'model') from public.business_expense_reviews where id=rid;
     end if;
   else
     update public.business_expense_suggestions set state='superseded' where review_id in(select id from public.business_expense_reviews where transaction_id=(result->>'transaction_id')::uuid and user_id=j.user_id and decision='unreviewed');
   end if;
   insert into public.business_expense_screened_inputs(user_id,transaction_id,fingerprint) values(j.user_id,(result->>'transaction_id')::uuid,result->>'fingerprint')
   on conflict(user_id,transaction_id) do update set fingerprint=excluded.fingerprint,screened_at=now();
 end loop;
 update public.business_expense_jobs set state=case when p_complete then 'complete' else 'queued' end,cursor_date=p_cursor_date,cursor_id=p_cursor_id,
 scanned=scanned+p_scanned,suggested=suggested+count_new,lease_token=null,lease_until=null,error_code=null,attempts=0,updated_at=now() where id=j.id;
 perform public.refresh_business_expense_briefing(j.user_id);
end $$;
create function public.enqueue_due_business_expense_scans() returns void language plpgsql security definer set search_path='' as $$
begin
 insert into public.business_expense_jobs(user_id,date_from,date_to,consent_revision)
 select s.user_id,(date_trunc('year',current_date)-interval '1 year')::date,current_date,s.revision
 from public.business_expense_settings s join public.user_entitlements e on e.user_id=s.user_id
 where s.enabled and e.tier='pro' and (e.status='active' or(e.status='trial' and e.trial_ends_at>now())or(e.status='grace' and e.grace_ends_at>now()))
 and not exists(select 1 from public.business_expense_jobs j where j.user_id=s.user_id and (j.state in('queued','running') or j.created_at>now()-interval '24 hours'))
 on conflict do nothing;
end $$;
revoke all on function public.commit_business_expense_batch(uuid,uuid,jsonb,date,uuid,integer,boolean),public.enqueue_due_business_expense_scans() from public,anon,authenticated;
grant execute on function public.commit_business_expense_batch(uuid,uuid,jsonb,date,uuid,integer,boolean),public.enqueue_due_business_expense_scans() to service_role;

create function public.business_expense_source_eligible(p_transaction_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select not t.pending and not t.is_superseded_duplicate and not t.is_stale_pending_duplicate and t.amount is not null and t.amount<>0 and t.amount not in ('NaN'::float8,'Infinity'::float8,'-Infinity'::float8)
 and case when o.flow_override is not null then o.flow_override='expense' else t.amount>0
   and lower(coalesce(t.personal_finance_primary,'')||' '||coalesce(t.personal_finance_detailed,'')||' '||coalesce(array_to_string(t.category,' '),'')) !~ '(transfer|payment|cash|deposit|withdrawal)'
   and lower(coalesce(o.merchant_name,t.merchant_name,t.name,'')) !~ '(\mzelle\M|\matm\M|\mwithdrawal\M|\mpayment to\M|\mautopay\M|\mmonthly payment\M|\m(card|loan) payment\M|\mtransfer (to|from)\M|\mmobile check deposit\M)' end
 from public.plaid_transactions t left join public.plaid_transaction_overrides o on o.transaction_id=t.id and o.user_id=t.user_id where t.id=p_transaction_id;
$$;
create function public.business_expense_input_version(p_transaction_id uuid) returns text language sql stable security definer set search_path='' as $$
 select md5(to_jsonb(t)::text||coalesce(to_jsonb(o)::text,'')) from public.plaid_transactions t
 left join public.plaid_transaction_overrides o on o.transaction_id=t.id and o.user_id=t.user_id where t.id=p_transaction_id;
$$;
create function public.business_expense_account_excluded(p_user_id uuid,p_account_id text,p_canonical_id text) returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(p_account_id=any(s.excluded_account_ids) or p_canonical_id=any(s.excluded_account_ids) or exists(
   select 1 from public.plaid_accounts pa where pa.user_id=p_user_id and(pa.account_id=p_account_id or pa.canonical_account_id=p_canonical_id)
   and ('persistent:'||pa.persistent_account_id)=any(s.excluded_account_ids)),false)
 from public.business_expense_settings s where s.user_id=p_user_id;
$$;
revoke all on function public.business_expense_account_excluded(uuid,text,text) from public,anon,authenticated;
grant execute on function public.business_expense_account_excluded(uuid,text,text) to service_role;
create function public.get_business_expense_scan_page(p_job_id uuid) returns jsonb language sql stable security definer set search_path='' as $$
 select coalesce(jsonb_agg(q.value order by q.date,q.id),'[]') from (
 select t.id,t.date,to_jsonb(t)||jsonb_build_object('correction',coalesce(to_jsonb(o),'{}'),'input_version',public.business_expense_input_version(t.id),'screening_excluded',public.business_expense_account_excluded(t.user_id,t.account_id,coalesce(t.canonical_account_id,t.account_id))) value
 from public.business_expense_jobs j join public.plaid_transactions t on t.user_id=j.user_id
 left join public.plaid_transaction_overrides o on o.transaction_id=t.id and o.user_id=t.user_id
 where j.id=p_job_id and not t.pending and not t.is_superseded_duplicate and not t.is_stale_pending_duplicate
 and t.date between j.date_from and j.date_to and (j.cursor_date is null or(t.date,t.id)>(j.cursor_date,j.cursor_id))
 order by t.date,t.id limit 25) q;
$$;

-- Private files use a dedicated filename prefix within the existing bucket.
create policy business_receipt_object_privacy on storage.objects as restrictive for all to authenticated
 using(bucket_id<>'CompanyDocuments' or name not like '%/expense-%' or split_part(name,'/',1)=auth.uid()::text)
 with check(bucket_id<>'CompanyDocuments' or name not like '%/expense-%' or split_part(name,'/',1)=auth.uid()::text);
create table public.business_expense_file_cleanup (
 id uuid primary key default gen_random_uuid(), user_id uuid not null, path text not null unique, created_at timestamptz not null default now()
);
alter table public.business_expense_file_cleanup enable row level security;
revoke all on public.business_expense_file_cleanup from public,anon,authenticated;
grant all on public.business_expense_file_cleanup to service_role;
create function public.track_business_expense_document() returns trigger language plpgsql security definer set search_path='' as $$
begin
 update public.business_expense_reviews set revision=revision+1,updated_at=now()
 where id in(select review_id from public.business_expense_documents where document_id=old.id);
 if tg_op='DELETE' and old.visibility='owner_private' and old.url like '%/expense-%' then
   insert into public.business_expense_file_cleanup(user_id,path) values(old.user_id,old.url) on conflict do nothing;
 end if;
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
create trigger business_expense_document_changes before update of name,url,visibility or delete on public.company_documents for each row execute function public.track_business_expense_document();
create function public.delete_business_expense_data(p_company_id uuid default null) returns void language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); ids uuid[]; docs uuid[]; begin
 if uid is null then raise exception 'Unauthorized'; end if;
 if p_company_id is not null and not exists(select 1 from public.companies where id=p_company_id and user_id=uid) then raise exception 'Entity not owned'; end if;
 select array_agg(r.id) into ids from public.business_expense_reviews r where r.user_id=uid and (p_company_id is null or exists(select 1 from public.business_expense_allocations where review_id=r.id and company_id=p_company_id) or exists(select 1 from public.business_expense_suggestions where review_id=r.id and company_id=p_company_id));
 select array_agg(document_id) into docs from public.business_expense_documents where review_id=any(ids);
 delete from public.business_expense_exports where user_id=uid and(p_company_id is null or company_id=p_company_id);
 delete from public.business_expense_reviews where id=any(ids);
 delete from public.company_documents d where d.id=any(docs) and d.user_id=uid and d.visibility='owner_private' and not exists(select 1 from public.business_expense_documents where document_id=d.id);
 delete from public.business_expense_screened_inputs where user_id=uid;
 update public.business_expense_jobs set state='cancelled',lease_token=null,lease_until=null where user_id=uid and state in('queued','running','paused');
 if p_company_id is null then update public.business_expense_settings set enabled=false,revision=revision+1,learning_reset_at=now() where user_id=uid;
 else update public.business_expense_profiles set enabled=false where user_id=uid and company_id=p_company_id; end if;
end $$;
create function public.delete_business_expense_company() returns trigger language plpgsql security definer set search_path='' as $$
begin
 delete from public.business_expense_reviews r where r.user_id=old.user_id and exists(select 1 from public.business_expense_allocations where review_id=r.id and company_id=old.id);
 return old;
end $$;
create trigger business_expense_company_cleanup before delete on public.companies for each row execute function public.delete_business_expense_company();
create function public.queue_business_expense_user_files() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.business_expense_file_cleanup(user_id,path) select old.id,name from storage.objects where bucket_id='CompanyDocuments' and name like old.id::text||'/expense-%' on conflict do nothing;
 return old;
end $$;
create trigger business_expense_user_cleanup before delete on auth.users for each row execute function public.queue_business_expense_user_files();

do $$ declare f record; begin
 for f in select oid::regprocedure signature from pg_proc where pronamespace='public'::regnamespace and proname like '%business_expense%' and proname in('business_expense_source_eligible','business_expense_input_version','get_business_expense_scan_page','track_business_expense_document','delete_business_expense_data','delete_business_expense_company','queue_business_expense_user_files') loop
 execute format('revoke all on function %s from public,anon,authenticated',f.signature);
 execute format('grant execute on function %s to service_role',f.signature);
 end loop;
end $$;
grant execute on function public.delete_business_expense_data(uuid) to authenticated;
create function public.queue_orphan_business_expense_files() returns void language sql security definer set search_path='' as $$
 insert into public.business_expense_file_cleanup(user_id,path)
 select split_part(o.name,'/',1)::uuid,o.name from storage.objects o
 where o.bucket_id='CompanyDocuments' and o.name ~ '^[0-9a-f-]{36}/expense-' and o.created_at<now()-interval '24 hours'
 and not exists(select 1 from public.company_documents d where d.url=o.name)
 on conflict do nothing;
$$;
revoke all on function public.queue_orphan_business_expense_files() from public,anon,authenticated;
grant execute on function public.queue_orphan_business_expense_files() to service_role;
create function public.track_business_expense_flow_correction() returns trigger language plpgsql security definer set search_path='' as $$
declare tid uuid; begin
 if tg_op='UPDATE' and old.flow_override is not distinct from new.flow_override then return new; end if;
 tid:=case when tg_op='DELETE' then old.transaction_id else new.transaction_id end;
 update public.business_expense_reviews set source_state='changed',revision=revision+1,updated_at=now()
 where transaction_id=tid and decision='confirmed' and source_state='active';
 if tg_op='DELETE' then return old; else return new; end if;
end $$;
create trigger business_expense_flow_correction after insert or update or delete on public.plaid_transaction_overrides
 for each row execute function public.track_business_expense_flow_correction();
revoke all on function public.track_business_expense_flow_correction() from public,anon,authenticated;
grant execute on function public.track_business_expense_flow_correction() to service_role;
