-- Manual, environment-specific rollout step AFTER migration 023 and the
-- cleanup-document-files function are verified in that same Supabase project.
-- Store its full HTTPS URL as Vault secret document_cleanup_function_url and
-- reuse the existing briefing_cron_secret / Edge CRON_SECRET pair. Verify the
-- URL's project ref by hand before executing this file; never paste secrets.
do $schedule$
declare
    v_url text;
    v_secret text;
begin
    select max(decrypted_secret) filter (
        where name = 'document_cleanup_function_url'
    ), max(decrypted_secret) filter (
        where name = 'briefing_cron_secret'
    ) into v_url, v_secret
    from vault.decrypted_secrets;
    if v_url is null or v_secret is null
       or v_url !~ '^https://[a-z0-9]+[.]supabase[.]co/functions/v1/cleanup-document-files$' then
        raise exception 'Missing or invalid document cleanup URL / cron secret';
    end if;
    perform cron.schedule('miloom-document-file-cleanup', '*/15 * * * *', $job$
        select net.http_post(
            url := config.function_url,
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'x-cron-secret', config.cron_secret
            ),
            body := '{}'::jsonb,
            timeout_milliseconds := 60000
        ) from (
            select max(decrypted_secret) filter (
                where name = 'document_cleanup_function_url'
            ) function_url, max(decrypted_secret) filter (
                where name = 'briefing_cron_secret'
            ) cron_secret
            from vault.decrypted_secrets
        ) config where config.function_url is not null
            and config.cron_secret is not null;
    $job$);
end;
$schedule$;
