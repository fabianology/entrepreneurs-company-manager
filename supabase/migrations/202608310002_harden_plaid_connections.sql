-- Keep superseded Plaid rows recoverable while excluding them from sync,
-- entitlement counts, and connection-health UI. Historical transactions retain
-- their plaid_item_id and remain available to the owner.

update public.plaid_items orphan
   set status = 'archived',
       error_code = 'SUPERSEDED_CONNECTION',
       updated_at = now()
 where orphan.status = 'active'
   and orphan.institution_id is null
   and exists (
       select 1
         from public.plaid_items replacement
        where replacement.user_id = orphan.user_id
          and replacement.plaid_institution_id = orphan.plaid_institution_id
          and replacement.institution_id is not null
          and replacement.status = 'active'
   );

-- If an older flow linked more than one active Item to the same visible
-- institution, retain the most recently successful row and archive the rest.
with ranked as (
    select id,
           row_number() over (
               partition by institution_id
               order by last_synced_at desc nulls last, created_at desc, id desc
           ) as position
      from public.plaid_items
     where institution_id is not null
       and status = 'active'
)
update public.plaid_items duplicate
   set status = 'archived',
       error_code = 'SUPERSEDED_CONNECTION',
       updated_at = now()
  from ranked
 where duplicate.id = ranked.id
   and ranked.position > 1;

-- One visible institution can have only one active Plaid Item. This does not
-- prevent a user from linking multiple legitimate logins for the same bank to
-- separate institution records.
create unique index if not exists idx_plaid_items_one_active_per_institution
    on public.plaid_items(institution_id)
    where institution_id is not null and status = 'active';

comment on index public.idx_plaid_items_one_active_per_institution is
    'Prevents duplicate active Plaid connections for one visible institution while allowing recoverable archived history.';
