# Phase 8 — Release Hardening

Phase 8 turns the Plaid, notification, and portfolio work into a release-ready
iOS build by tightening security boundaries, making failure behavior safe, and
recording the final verification gate.

## 8.0 Release-readiness audit

- [x] Confirm the local secrets file is ignored and absent from Git history.
- [x] Review client configuration, entitlements, privacy manifest, diagnostics,
  and the release test surface.
- [x] Identify release blockers separately from normal compiler warnings.

## 8.1 Client safety and privacy

- [x] Remove the unused Gemini API-key entry from the iOS app bundle; AI requests
  use authenticated Supabase Edge Function proxies.
- [x] Replace raw error printing on financial sync, sharing, AI, and audio paths
  with aggregate-only diagnostics.
- [x] Make rare Apple sign-in nonce/callback failures recoverable rather than
  terminating the app.

## 8.2 Build and regression gate

- [x] Run the iPhone 17 Pro test suite after hardening changes.
- [x] Triage remaining warnings into release blockers, follow-ups, or third-party
  dependency warnings.
- [x] Confirm the release bundle contains no Gemini API-key configuration.

### 8.2 validation evidence

- The iPhone 17 Pro XCTest suite and an optimized Release simulator build pass.
- The generated Release `Info.plist` contains Supabase public configuration but
  no `GeminiAPIKey` entry.
- Remaining warnings are not release blockers: redundant optional handling and
  unused locals are cleanup work; SDK deprecations and the AVSpeechSynthesizer
  Sendable warning require future API/concurrency migration; duplicate Xcode
  compile-source entries should be removed in a separate project-file cleanup.

## 8.3 Production handoff

- [x] Deploy the exact-minute `send-briefings` worker fix before relying on a
  custom weekly briefing time.
- [ ] Retest one live briefing or transaction-review Inbox route after backend
  deployment.
- [x] Prepare the signed-device release checklist.
- [ ] Commit the Phase 8 changes after device and backend handoff checks.

### Signed-device release checklist

1. Install the signed Release build over a prior build, launch it, and sign in.
2. Verify the portfolio loads companies and financial institutions without a
   duplicate import or a slow-query error.
3. Open a Plaid institution, run one manual sync, then confirm its cards,
   accounts, and transaction count refresh correctly.
4. Open Notifications & Alerts, verify the device is Ready, and send the
   private test notification. It must contain no merchant, balance, account,
   credential, or document data.
5. Open Inbox, verify existing alerts render, and confirm an available alert
   opens its expected portfolio destination.
6. Scan or upload one non-sensitive test document, verify its preview, then
   remove the test document.
7. Sign out and sign back in; confirm companies, notification preferences, and
   financial data reload without showing another user's data.

### Deployment evidence

- The linked Miloom Supabase project's `send-briefings` Edge Function is active
  at version 6 with the exact-minute delivery-window implementation. Deployment
  only uploaded the function; it did not invoke the worker or create alerts.
