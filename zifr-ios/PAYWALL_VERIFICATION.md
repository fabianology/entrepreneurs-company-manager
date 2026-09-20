# Miloom paywall verification

Implemented the final concept from the **PAYWALL** task (`01a08776-6384-7332-9e1b-ea7cf1498232`), using its `miloom-final-paywall.html` as the design reference.

## Implementation

- `Zifr/Views/PremiumUpgradeView.swift`: native presentation, champagne accent, compact clear-glass Owner Briefing example, Free/Pro table, expandable benefits, Monthly selected initially to match the supplied screenshot, plan cards, payment timeline, purchase action, and legal/restore links. The system sheet supplies the rounded screen edges and home indicator. Content scrolls on smaller screens.
- StoreKit supplies localized prices, billing periods, introductory-offer eligibility, free-trial duration, paid introductory terms, annual savings, and monthly equivalents. Loading or missing products cannot be purchased; failed/partial catalog loading can be retried.
- `AccessController.hasProSubscription` distinguishes a real subscription from the Debug feature unlock. `AdminSettingsView.swift` uses it for the Upgrade entry; `PremiumUpgradeView.swift` uses it for purchase-versus-management presentation. No special launch argument is needed to see the paywall.
- Existing `PremiumGate` copy and account-token purchase integration remain connected. Purchase/restore are mutually exclusive; success clears the pending gate and dismisses the paywall. Pending approval is handled by the existing transaction listener.
- Locally verified purchases remain available during server outages, and unfinished transactions are retried when the paywall opens. Expired, refunded, or superseded transactions cannot grant access. `AccessController.swift` adds local revocation handling and excludes upgraded transactions and the just-invalidated transaction from its StoreKit fallback.
- Reduced transparency replaces the preview's blurred backdrop with an opaque surface. No iOS 26-only glass API is required; the deployment target remains iOS 17.
- `Zifr.xcodeproj/project.pbxproj` registers `PaywallStoreKitTests.swift` and the test-only `MiloomPaywall.storekit` resource. The shared Debug Run action now selects this local StoreKit configuration so simulator runs have products and eligible offers available. Shipping product lookup still uses StoreKit.

## Automated verification

On September 9, 2026, the `Zifr` scheme built and ran on the iPhone 15 Pro simulator with **iOS 17.5**, using Xcode 26.4. The final selected suite passed **78 tests with zero failures**: 14 paywall/StoreKit tests and 64 existing premium engine tests. The completed-purchase refund scenario also passed five consecutive repetitions.

The StoreKit tests cover:

- A development feature unlock does not masquerade as a subscription or hide the purchase UI; verified subscriptions still show management.
- Localized product prices, calculated savings, eligible trials, and ineligible subscribers.
- Pay-as-you-go and upfront introductory offers without a false free-trial claim.
- Successful purchase, account-token preservation, and eligibility after purchase.
- User cancellation and Ask to Buy approval through the transaction listener.
- Empty restore, successful restore, restore errors, and expired/refunded subscriptions.
- Refund updates removing local Pro access.
- Server failure preserving access and an unfinished transaction; successful retry finishing it.
- Product-load errors clearing stale prices and a successful retry.
- Rendered yearly/trial, monthly/no-trial, company/expanded/reduced-transparency, and Owner Briefing states.

Run from the repository root with an available iOS simulator:

```sh
xcodebuild -project zifr-ios/Zifr.xcodeproj -scheme Zifr \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5' \
  -derivedDataPath /tmp/miloom-paywall-build \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO \
  -only-testing:ZifrTests/PaywallStoreKitTests \
  -only-testing:ZifrTests/PremiumEngineTests test
```

The local StoreKit fixture's $12.99/$99.99 prices and seven-day trial are **test data**, not production prices. Tests use Apple's StoreKit purchase, entitlement, update, and restore APIs, while substituting the external Supabase entitlement verifier. An authenticated App Store sandbox/TestFlight purchase against the deployed Supabase endpoint was not performed.

## Viewing the purchase design in Debug

Debug feature access remains unlocked, but the synthetic `debug-unlocked` entitlement no longer selects subscription management. The normal account entry now says Upgrade and opens the full paywall without launch arguments. Real subscriptions retain their management view. Use `-MiloomEntitlementState storekit` for entitlement testing. The Run action selects `ZifrTests/MiloomPaywall.storekit` for local pricing/offers; set StoreKit Configuration to None when testing App Store products.

The actual app was rebuilt and opened through Account on the iPhone 17 Pro / iOS 26.4 simulator. The comparison, plans, trial timeline, CTA and footer were visible together. Switching between Yearly and Monthly updated the renewal amount and cadence; the benefits disclosure expanded and collapsed. The purchase action reached an Apple Account sign-in prompt in that simulator, and Not Now returned to the paywall. No Apple Account was signed in and no real purchase was made.

Screenshots were visually inspected at 375- and 393-point widths. Expanded content and reduced-transparency rendering were also inspected. Screenshots use a taller capture canvas to include the footer; on smaller devices the native scroll view keeps all actions reachable.

All changes are uncommitted. Unrelated backend and profile edits in the shared workspace were preserved.

## TestFlight catalog incident — September 20, 2026

- App Store Connect was inspected after build 12 showed `Loading…` on a physical TestFlight install. Miloom has no subscription group or subscription products configured there, while the app requests `com.miloom.premium.monthly` and `com.miloom.premium.yearly`. StoreKit therefore has no catalog to return; this is not evidence of a device connectivity failure.
- The Paid Apps Agreement is `New`, not active. App Store Connect also reports that legal-entity information must be updated before the agreement can be signed. Both the agreement and real App Store products are external prerequisites for a TestFlight purchase.
- The app-side unavailable state now keeps a close control visible while the paywall scrolls, adds `Continue with Free`, changes the disabled purchase control into `Try loading prices again`, avoids blaming the network, and retries a missing catalog when the app becomes active.
- A normal iPhone 17 Pro / iOS 26.4 simulator build passed. The focused paywall visual test passed. The complete StoreKit test class was attempted twice but the Xcode test runner stalled waiting for workers to materialize and was interrupted; no full-suite pass is claimed for this follow-up.
- The local `$12.99` monthly, `$99.99` yearly, and seven-day trial fixture remains test data. Production prices and trial terms must be chosen before creating the App Store products. No App Store configuration, upload, commit, push, or deployment was performed in this follow-up.

## Included TestFlight beta access — September 20, 2026

- Release builds now recognize a verified App Store sandbox `AppTransaction` as TestFlight beta access. The sandbox receipt filename is used as an immediate fallback so feature gates are open from first render, even before the asynchronous StoreKit verification finishes.
- Beta access presents an in-memory Pro snapshot to native feature gates and `AppState`, dismisses any gate that raced with entitlement refresh, and labels the Account card `MILOOM PRO — BETA ACCESS`. It is never written into the cached paid entitlement.
- Production App Store transactions do not receive the beta override. Xcode's local environment is also excluded, and Debug builds retain the existing launch-argument states so the purchase UI remains testable.
- Apple documents that TestFlight apps use the sandbox environment. When the same code is distributed from the production App Store, StoreKit reports the production environment and the normal Free/Pro subscription rules apply automatically.
- Supabase Edge Functions independently meter hosted AI and live voice requests from the server entitlement. This native change removes the paywall and native Pro gates for TestFlight; fully raising those server quotas for beta accounts requires a separately authorized backend entitlement change.
- Verification: Debug and Release simulator builds passed on Xcode 26.4. The focused sandbox/production/Xcode environment guard and the existing development-unlock regression both passed. Existing project warnings remain unrelated.
- Miloom 1.0 build 13 was uploaded with explicit user approval, completed Apple processing, and entered Testing for the existing Devs and Family + Friends groups. Automatic tester notification was enabled. App Store Connect build ID: `eb784a39-9b2a-4ac1-9479-6a6faf64ad29`.
