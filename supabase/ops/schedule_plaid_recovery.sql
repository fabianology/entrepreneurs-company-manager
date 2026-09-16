-- Run only after deploying the cached-balance version of plaid-nightly-sync.
-- Before running, store a dedicated random secret in both the Edge Function
-- secret PLAID_SYNC_CRON_SECRET and Vault's plaid_sync_cron_secret. Also store
-- the project's anon JWT in Vault's plaid_sync_anon_key for gateway verification.
-- Never put secret values in this file or logs.
-- Target: xxqdytdbpiqjilhutvhz. Review the URL before use in another project.
-- Re-running updates this named job instead of creating a duplicate.
BEGIN;

DO $preflight$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM vault.secrets WHERE name = 'plaid_sync_cron_secret'
  ) THEN
    RAISE EXCEPTION 'Configure plaid_sync_cron_secret in Vault first';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM vault.secrets WHERE name = 'plaid_sync_anon_key'
  ) THEN
    RAISE EXCEPTION 'Configure plaid_sync_anon_key in Vault first';
  END IF;
  IF EXISTS (
    SELECT 1 FROM cron.job
    WHERE command ILIKE '%plaid-nightly-sync%'
      AND jobname <> 'miloom-plaid-nightly-sync'
  ) THEN
    RAISE EXCEPTION 'Another Plaid recovery job exists; review it before adding a duplicate';
  END IF;
END;
$preflight$;

SELECT cron.schedule(
  'miloom-plaid-nightly-sync',
  '0 2 * * *', -- 02:00 UTC daily; independent of Plaid's bank-update schedule.
  $job$
    SELECT net.http_post(
      url := 'https://xxqdytdbpiqjilhutvhz.supabase.co/functions/v1/plaid-nightly-sync',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'plaid_sync_anon_key'
          LIMIT 1
        ),
        'x-cron-secret', (
          SELECT decrypted_secret
          FROM vault.decrypted_secrets
          WHERE name = 'plaid_sync_cron_secret'
          LIMIT 1
        )
      ),
      body := '{}'::jsonb,
      timeout_milliseconds := 60000
    );
  $job$
);

COMMIT;
