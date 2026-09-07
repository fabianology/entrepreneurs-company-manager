-- Separates recurring obligations into automatically classified bills and subscriptions.
-- Existing rows remain automatic and can be manually overridden by the owner.
begin;

alter table public.subscriptions
    add column if not exists service_type text;

update public.subscriptions
set service_type = 'automatic'
where service_type is null
   or service_type not in ('automatic', 'bill', 'subscription');

alter table public.subscriptions
    alter column service_type set default 'automatic',
    alter column service_type set not null;

alter table public.subscriptions
    drop constraint if exists subscriptions_service_type_check;

alter table public.subscriptions
    add constraint subscriptions_service_type_check
    check (service_type in ('automatic', 'bill', 'subscription'));

comment on column public.subscriptions.service_type is
    'Owner-selectable recurring service classification; automatic delegates classification to the client.';

commit;
