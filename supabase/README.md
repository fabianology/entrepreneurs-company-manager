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

Deploy the migration first, then deploy `sync-entitlement`,
`app-store-notifications`, and `send-briefings`. Configure App Store Server
Notifications V2 to target the deployed notification function. Invoke
`send-briefings` every 15 minutes; it claims one private delivery per user's local
date and never includes company names, balances, credentials, or document names in
the APNs payload.
