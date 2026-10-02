-- Disposable database only. Hosted Auth already has these columns.
alter table auth.users add column email_confirmed_at timestamptz,
    add column is_anonymous boolean not null default false;
update auth.users set email_confirmed_at = now()
 where id in ('00000000-0000-0000-0000-000000000001',
              '00000000-0000-0000-0000-000000000003');
