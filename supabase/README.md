# Miloom Supabase backend

This directory tracks the database and Edge Function changes required by Miloom Pro.

Before deployment, configure these function secrets:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `APPLE_BUNDLE_ID` (`com.vibing.miloom`)
- `APPLE_APP_ID` (numeric App Store application ID; required in production)
- `APPLE_ENVIRONMENT` (`Sandbox` or `Production`)
- `APPLE_ROOT_CA_B64` (comma-separated DER certificates encoded as base64)
- `APNS_TEAM_ID`, `APNS_KEY_ID`, and `APNS_PRIVATE_KEY`
- `CRON_SECRET` (use it as the `x-cron-secret` header on the hourly job)
- `PLAID_CLIENT_ID`, `PLAID_SECRET`, and `PLAID_ENV`
- `PLAID_WEBHOOK_URL` (recommended; defaults to
  `$SUPABASE_URL/functions/v1/plaid-webhook`)

Deploy the migration first, then deploy `sync-entitlement`,
`app-store-notifications`, and `send-briefings`. Configure App Store Server
Notifications V2 to target the deployed notification function. Invoke
`send-briefings` every 15 minutes; it claims one private delivery per user's local
date and never includes company names, balances, credentials, or document names in
the APNs payload.

## Event-driven Plaid transaction sync

Deploy `202608310007_plaid_event_sync.sql` before deploying the Plaid functions.
Then deploy `plaid-webhook`, `create-link-token`, `exchange-public-token`, and
`plaid-nightly-sync`. Plaid cannot attach a Supabase user JWT, so the webhook must
be deployed with platform JWT verification disabled; the function instead
requires Plaid's signed `Plaid-Verification` JWT and validates its age, ES256
signature, verification-key status, and exact raw-body SHA-256 hash.

```sh
supabase functions deploy plaid-webhook --no-verify-jwt
supabase functions deploy create-link-token
supabase functions deploy exchange-public-token
supabase functions deploy plaid-nightly-sync
```

Keep `plaid-nightly-sync` scheduled as a recovery sweep. It also registers the
webhook on pre-existing Items once and then uses the same serialized,
cursor-based `/transactions/sync` engine as webhook deliveries and manual sync.
Do not expose the webhook function behind an additional proxy that rewrites or
reformats its JSON body, because Plaid's signature covers the exact raw bytes.

## Portfolio alert evaluation

Deploy `202608310008_miloom_alert_rules.sql` before the alert-aware Plaid and
briefing functions. The migration creates user-owned category rules,
deduplicated private alert events, and service-only balance snapshots. It also
adds the date fields used for upcoming-payment and expiration evaluation.

```sh
supabase functions deploy plaid-webhook --no-verify-jwt
supabase functions deploy plaid-nightly-sync
supabase functions deploy send-briefings --no-verify-jwt
```

`send-briefings` must receive the configured `CRON_SECRET` in its
`x-cron-secret` header. Alert evaluation can create private in-app records, but
does not send alert-event push notifications. Weekly and critical briefing push
delivery remains independently opt-in.
