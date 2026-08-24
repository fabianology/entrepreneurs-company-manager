# Zifr iOS (Miloom) Project Handoff

This is a verified context document for the native Swift iOS application in `zifr-ios`. It is not a task list or an instruction file. The current code, Git state, and the user's direct requests are authoritative when they differ from this snapshot.

Snapshot reviewed on 2026-08-24 at commit `0ef7405c`.

## Scope and product context

- This handoff covers only the native iOS app. The sibling React Native, web, and desktop projects are out of scope.
- The Xcode project and scheme are named `Zifr`; the current customer-facing display name and bundle identifier use `Miloom` and `com.vibing.miloom`.
- Prior development described the product as a dark, high-density workspace for entrepreneurs managing companies or entities, financial accounts, subscriptions, and documents. Confirm product or roadmap changes with the owner rather than treating this description as a requirement.
- The established interface uses dark surfaces, glass/material effects, compact typography, pill-shaped active controls, and haptic feedback. Reuse the existing tokens and components before introducing new visual patterns.

## Verified architecture

- The app targets iOS 17 and uses Swift 5.9 settings.
- The UI is primarily SwiftUI, with UIKit and Apple-framework bridges for camera scanning, document scanning, PDF display, Safari, CloudKit sharing, StoreKit, and authentication.
- `ZifrApp.swift` creates and injects `AuthViewModel`, `AppState`, and `OnboardingStateManager`. Authenticated users enter `RootView`, which presents `DashboardView`.
- `AppState` is the in-memory source of truth for companies, subscriptions, institutions, cards, loans, documents, transactions, shares, activity logs, notifications, and preferences.
- `AppViewModel` owns navigation, optimistic CRUD operations, calculations, and global search. Failed writes generally restore the prior in-memory value and expose an error through `AppState`.
- `DataRepository` loads portfolio data from Supabase, including loan payments and Plaid transactions. It performs a lightweight preferences query before concurrent startup requests to reduce observed token-refresh contention.
- There is no durable local cache for the main Supabase-backed portfolio. A small company-assignment override is stored in `UserDefaults`, and the authentication SDK persists its own session.

## Backend and integrations

- Supabase provides authentication, PostgreSQL access, Storage, RPC calls, and Edge Functions.
- Client code references tables including `companies`, `subscriptions`, `institutions`, `financial_cards`, `loans`, `loan_payments`, `company_documents`, `plaid_transactions`, `resource_shares`, `activity_logs`, `app_notifications`, and `user_preferences`.
- Email/password, Google, and Apple sign-in are implemented. Biometrics locally unlock a cached authenticated session; biometrics are not a separate Supabase identity provider.
- Plaid Link is integrated through the `plaid-link-ios-spm` package. Link-token creation, token exchange, and sync requests use authenticated Supabase Edge Functions.
- Gemini REST and live voice requests use authenticated Supabase Edge Function proxies. The app also contains a direct Google favicon/logo lookup path.
- Password-like fields are encrypted by `SecurityService` with a device Keychain-backed key before Supabase writes and decrypted after reads.
- Document workflows use VisionKit/Vision for scanning and OCR, PDFKit for viewing, and Supabase Storage for uploaded files.

## Implemented product areas

- Portfolio dashboard and company/entity navigation.
- Company, subscription, institution, card, loan, loan-payment, and document create/edit/delete flows.
- Financial account and transaction views, including `TransactionFeedView`.
- Recurring-transaction detection and a `DetectedSubscriptionsSheet` flow that can create permanent subscriptions.
- Document scanning, OCR categorization, PDF generation, upload, and viewing.
- Global cross-domain search.
- Entity/resource sharing, collaborator management, activity logs, and in-app notification data.
- Multi-step onboarding and spotlight overlays in `Views/Onboarding/SpotlightOverlay.swift`.
- Gemini portfolio Q&A plus text and live-audio assistant flows.
- Premium purchase code using StoreKit.

## Recent work

- Commit `0ef7405c` added loan-payment persistence and ledger behavior, borrower/lender terminology, balance recalculation, paid-off actions, financial layout changes, and updated glass styling.
- Commit `94264d0d` updated login design, logo assets, demo behavior, and loan colors.
- Commit `2c14aef8` revised empty states, demo seeding, and sheet presentation.
- Commit `4a4d0149` removed LogoKit usage and restored Google favicon fetching.

## Verified gaps and risks

- There is currently no unit-test or UI-test target/source coverage.
- A clean Debug simulator build succeeded on 2026-08-24 at commit `0ef7405c` using Xcode 26.4, the iOS 26.4 SDK, and the booted iPhone 17 Pro simulator. The build used isolated temporary DerivedData and produced `Zifr.app` for `com.vibing.miloom` with a minimum OS of iOS 17.0. A runtime smoke test has not yet been recorded.
- The successful baseline still emits warnings: deprecated Apple/Supabase APIs, redundant nil-coalescing on non-optional values, unused values and ignored `try?` results, a Swift concurrency `Sendable` warning, unnecessary `try`/`await` handling, and duplicate source-file entries in the Xcode project.
- Push-notification entitlements and notification database models exist, but no runtime `UserNotifications` integration was found.
- Several source files are very large, including subscription editing, settings, assistant, documents, shared components, and entity-home views. Refactor only as part of a scoped task; do not begin a broad rewrite during feature work.
- `AppViewModel` centralizes several domains. Treat its size as technical debt, not proof of a current runtime defect.
- The repository tracks approximately 12,691 files under `zifr-ios/build` (about 1.9 GB locally) plus an Xcode user-state file, despite current ignore rules. Cleanup should be a separate, explicitly approved Git task.
- `SupabaseService` contains a hard-coded anonymous-key fallback. Supabase anonymous client keys are not server secrets, but duplicating configuration in source is a maintenance and rotation risk.
- Naming remains mixed between Zifr and Miloom. Do not rename targets, symbols, bundle identifiers, or entitlements without a dedicated migration plan.

## Build and local configuration

- Open `zifr-ios/Zifr.xcodeproj` and use the shared `Zifr` scheme.
- `project.yml` declares iOS 17, Swift 5.9, and Xcode 16-era generation settings. The project was recognized locally by Xcode 26.4.
- Swift Package Manager pins Supabase, Google Sign-In/AppAuth, Plaid LinkKit, and their transitive dependencies in `Package.resolved`.
- `Zifr/Secrets.local.xcconfig` is present locally and ignored by Git. Never print, stage, or commit secrets.
- Current entitlements include Sign in with Apple, associated domains, CloudKit, and development push notifications. Device signing and production entitlement readiness have not been verified in this transition.

## Owner decisions still needed

- Product priorities and roadmap order are not established by this handoff.
- Offline persistence, architectural decomposition, repository cleanup, notification delivery, security/configuration cleanup, and automated tests are candidates for separate scoped work—not automatic next steps.
- Before substantial feature work, the safest next transition step is a short simulator smoke test without combining it with fixes or refactoring.
