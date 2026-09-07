-- Reuse the existing CRON_SECRET / briefing_cron_secret convention. No secret
-- values are embedded in a job definition. An unset URL leaves the job inert.
do $migration$
begin
 if to_regnamespace('cron') is not null and to_regnamespace('net') is not null and to_regclass('vault.decrypted_secrets') is not null then
   perform cron.schedule('business-expense-screening','*/2 * * * *',$job$
     select net.http_post(
       url := config.function_url,
       headers := jsonb_build_object('Content-Type','application/json','x-cron-secret',config.cron_secret),
       body := '{}'::jsonb,timeout_milliseconds := 60000
     ) from (
       select max(decrypted_secret) filter(where name='business_expense_function_url') function_url,
              max(decrypted_secret) filter(where name='briefing_cron_secret') cron_secret
       from vault.decrypted_secrets where name in('business_expense_function_url','briefing_cron_secret')
     ) config where config.function_url is not null and config.cron_secret is not null;
   $job$);
 end if;
end;
$migration$;
