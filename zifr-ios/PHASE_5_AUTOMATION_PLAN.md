# Phase 5 — Automation and Alerts

This checklist records the verified starting point and implementation order for Phase 5. It covers the native Miloom iOS experience. Backend changes are identified separately because they require an explicit scope expansion before implementation.

## 5.0 Foundation audit — complete

### Already implemented

- APNs entitlement and application delegate registration.
- Authenticated device-token persistence in `device_push_tokens`.
- Private push copy that exposes only an item count on the lock screen.
- Weekly briefing schedule, timezone, weekly enablement, and immediate-critical-alert preferences.
- Server-side weekly and critical delivery deduplication.
- Owner Briefing deep-link handling from the existing `owner_briefing` push route.
- In-app `app_notifications` loading and resource identifiers in the notification model.
- Manual and scheduled Plaid refresh entry points.

### Verified gaps

- Plaid Link tokens do not register a webhook URL.
- No Plaid webhook receiver exists in the repository.
- Transaction refresh uses a complete two-year `/transactions/get` download instead of cursor-based `/transactions/sync` deltas.
- The checked-in cron SQL still contains a placeholder project URL.
- Push taps only route to Owner Briefing; resource-specific notification routes are not implemented.
- Notifications are fetched but there is no dedicated notification inbox/read-state workflow.
- Alert preferences are limited to one global critical-alert toggle; there are no per-category or amount thresholds.
- The app has no background refresh task. The primary automation path should therefore be server-driven, with app activation used only as a fallback refresh.

## 5.1 Event-driven Plaid sync — complete

- [x] Add a Plaid webhook endpoint with signature verification and safe event logging.
- [x] Register the webhook URL when creating a Link token and backfill existing Items on refresh.
- [x] Replace full-history transaction polling with `/transactions/sync` and persist each Item cursor.
- [x] Handle added, modified, and removed transactions idempotently.
- [x] Coalesce duplicate webhook deliveries and concurrent sync requests per Plaid Item.
- [x] Retain manual **Sync Latest Data** as a recovery action.
- [x] Surface `requires_reauth`, delayed-data, and partial-sync states in the existing institution actions section.
- [x] Add server tests for cursor pagination restart and enriched transaction mapping; preserve per-Item failure isolation in the recovery sweep.
- [x] Deploy the migration and all four production Edge Functions.
- [x] Run one authenticated **Sync Latest Data** action to initialize and verify existing Items.

Production verification: all six currently linked Plaid Items initialized a cursor, registered the webhook, and synced successfully with zero webhook failures. Five legacy rows from June 2026 remain marked active but have no linked institution; they are excluded from the app refresh and were intentionally left unchanged for a separate cleanup decision.

## 5.2 Alert rules — complete

- [x] Introduce user-owned alert rules for large transactions, possible duplicates, unusual spending, balance changes, upcoming payments, expiring cards/documents, and disconnected institutions.
- [x] Start with conservative defaults and keep every category independently switchable.
- [x] Evaluate rules after a successful data sync and during the scheduled recovery sweep, not on device.
- [x] Store only the minimum resource reference and private summary needed for the in-app experience.
- [x] Deduplicate alerts by user, rule, source resource, and event version.
- [x] Deploy the database contract and alert-aware production functions with push delivery still opt-in.
- [x] Run one authenticated sync to verify production alert evaluation and balance-snapshot initialization.

Production deployment seeded seven rules for each of nine users (63 total): five conservative categories enabled per user, unusual-spending and balance-change rules disabled, zero alert events created during deployment, and zero users opted into push delivery by default.

The first authenticated smoke sync exposed a production-only seed mismatch: omitted rule configuration values were serialized as `null` even though `alert_rules.config` is non-null. Plaid refreshes still completed because alert evaluation is isolated. The evaluator now always seeds `{}` for rules without custom configuration, regression coverage passes, and the dependent functions have been redeployed.

Post-fix production verification refreshed all four linked institutions owned by the test user, initialized nine account balance baselines, recorded zero active Plaid Item errors, produced zero duplicate alerts, and logged zero evaluator failures. No alert events were expected from the current data and conservative enabled rules.

## 5.3 Notification inbox and deep links

- Add a typed notification route shared by push payloads and `app_notifications`.
- Route to Owner Briefing, institution actions, a transaction, or the transaction review queue.
- Add an in-app inbox with unread count, mark-read, and mark-all-read actions.
- Defer a route until authentication and portfolio loading are complete.
- Keep sensitive merchant, institution, balance, account, and document details out of push payloads.

## 5.4 Preferences and weekly summary

- Extend Briefing Schedule into an Automation & Alerts screen.
- Add per-alert switches and configurable large-transaction/balance thresholds.
- Show notification permission status and a direct Settings recovery action when permission is denied.
- Add a last-delivered/next-scheduled summary and a private test-notification action.

## 5.5 Validation and release readiness

- Test webhook replay, out-of-order delivery, throttling, expired Plaid credentials, and one-bank failure isolation.
- Verify notification routing from terminated, backgrounded, and foreground app states.
- Verify all lock-screen copy remains private.
- Verify development and production APNs environments and device-token lifecycle.
- Run the iPhone 17 Pro simulator suite and a signed physical-device smoke test.

## Completion criteria

Phase 5 is complete when new Plaid activity reaches Miloom without requiring the app to be open, transaction changes are incrementally and idempotently applied, users can control which alerts they receive, notification taps open the correct in-app destination, and failure states remain visible and recoverable without exposing private financial details.
