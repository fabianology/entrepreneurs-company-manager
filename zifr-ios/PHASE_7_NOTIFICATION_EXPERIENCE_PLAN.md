# Phase 7 — Notification Experience

Phase 7 makes notification controls easy to find, explains the difference between in-app and push delivery, and verifies that every preference produces predictable behavior without exposing private financial details.

## 7.0 Experience audit

- [x] Trace the current notification settings, authorization, persistence, and delivery flows.
- [x] Confirm that the existing Automation & Alerts sheet is the single source of truth for weekly briefings, immediate alerts, and portfolio alert rules.
- [x] Identify the primary usability gap: notification controls require navigating through Briefing, the reminder queue, and its toolbar.

## 7.1 Direct settings access

- [x] Add a first-class Notifications & Alerts entry to Account & Settings.
- [x] Reuse the existing Automation & Alerts sheet so both entry points edit the same preferences.
- [x] Verify navigation, loading, cancelling, and reopening on the iPhone 17 Pro simulator.
- [x] Verify editing, saving, and persisted values without changing the owner's preferred notification choices unintentionally.

### 7.1 validation evidence

- The iPhone 17 Pro iOS 26.4 build succeeds and launches.
- Account & Settings exposes Notifications & Alerts immediately below Inbox.
- The entry opens Automation & Alerts with the current notification permission,
  weekly schedule, delivery history, and immediate-alert state loaded.
- Cancelling returns to Account & Settings and the sheet reopens successfully.
- Saving the existing configuration preserved the owner's choices and reloaded
  the same summary after a cold launch and a full sign-out/sign-in cycle.

## 7.2 Delivery clarity

- [x] Clearly distinguish the in-app inbox from iPhone push notifications.
- [x] Show current permission and device-registration health without exposing device identifiers.
- [x] Provide actionable recovery when notifications are disabled or registration fails.

### 7.2 validation evidence

- The iPhone 17 Pro simulator identifies the in-app inbox as available even when
  push delivery is unavailable.
- Push permission and registration are separate status rows; the simulator is
  correctly labeled as physical-device-only instead of reporting a false failure.
- No APNs token or device identifier is rendered. Denied permission links to
  iPhone Settings, while failed or missing registration offers a retry action.
- The updated iPhone 17 Pro iOS 26.4 build succeeds and launches.

## 7.3 Preference feedback

- [x] Summarize enabled delivery modes and alert-rule count on the settings entry.
- [x] Validate thresholds and explain when transaction-based rules are evaluated.
- [x] Confirm saved preferences persist across sign-out and sign-in.

### 7.3 implementation notes

- Account & Settings summarizes weekly/immediate delivery and the enabled rule
  count after rules load; it shows a loading label instead of a misleading zero.
- Save remains unavailable until the complete alert-rule set is loaded.
- Threshold fields are required only while their corresponding rule is enabled,
  with specific validation messages for transaction and balance thresholds.
- Saving the unchanged configuration produced the expected `Weekly push · 5
  alert rules` summary, and that summary survived a cold app relaunch.
- A full sign-out and sign-in completed successfully. Account & Settings then
  reloaded the same `Weekly push · 5 alert rules` summary.

## 7.4 End-to-end validation

- [x] Exercise a private test notification on simulator and physical device where supported.
- [x] Verify in-app inbox routing for briefings and transaction review alerts.
- [ ] Run the iPhone 17 Pro suite and a signed physical-device smoke test.
- [x] Record remaining production scheduler or APNs checks explicitly.

### 7.4 validation evidence

- The iPhone 17 Pro iOS 26.4 simulator scheduled the private test notification
  successfully. Its copy contains no financial or account details, and the UI
  correctly labels APNs registration as physical-device-only.
- Account & Settings opens the Inbox successfully; the current test account has
  no live alert rows. Typed route unit coverage verifies owner-briefing,
  transaction, and transaction-review destinations; seeded backend rows are
  still needed for a live tap-through check.
- The iPhone 17 Pro XCTest suite passed. A signed physical-device smoke test is
  not available in this environment and remains an explicit release check.
- Production checks remaining: Supabase scheduler delivery for owner briefings
  and transaction-review alerts, APNs token registration on a signed device, and
  foreground/background/tap routing from a real push payload.

## Completion criteria

Phase 7 is complete when notification controls are directly discoverable, permission and delivery state are understandable and recoverable, preference changes persist, and in-app plus push delivery paths pass privacy-safe end-to-end validation.
