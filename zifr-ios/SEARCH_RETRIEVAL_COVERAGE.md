# Shared retrieval and calculations

Implementation branch: `feature/universal-search`. Native iOS only; no new dependencies, database contracts, entitlements, or minimum-OS change.

## Entry points

- **Search:** immediate local matching and calculations. The Company, Type, and Date controls remain in the compact sheet; Bills and Subscriptions are separate Type choices. An unresolved question can be interpreted by Gemini on Search submission through the existing access gate. No model requests run while typing.
- **Gemini text and Live:** the same `searchPortfolio` declaration accepts a validated `PortfolioQuery`. Both use the same executor and bounded evidence. The model explains app-computed results and can retrieve record details or traverse links by source ID.
- **Siri/Shortcuts:** `AskMiloomIntent` returns a spoken/value answer from the same executor. `ReadMiloomRecordIntent` uses `MiloomRecordEntity`/`EntityStringQuery`. Existing Search shortcuts still open the sheet. Local-device authentication and an authenticated, matching app session are required. Cold launch/loading has a bounded wait, followed by an explicit open/unlock fallback. No private records are donated to Spotlight.

## Data inventory

| Area | Search/retrieval coverage | Limits / source |
|---|---|---|
| Companies | Name, structure, description, website | Authorized company records |
| Bills and subscriptions | Resolved classification, manual/automatic basis, status, cost/currency, billing cycle, renewal, renewal mode, payment links, website, redacted notes, linked email purpose | Uses the classification shown by the app; automatic classification remains a heuristic |
| Add-ons | Separate type, cost/cycle, status, next renewal, purpose, payment link and parent | Separate cost components prevent double counting and preserve mixed bill/subscription classifications; open parent service to edit |
| Cards | Identity/ending, holder, status, current balance, limit, APR/promotion, stored payment/due information, linked bank facts, notes | No full PAN/password; USD default identified if no linked currency source |
| Banks and accounts | Bank identity/connection/sync; account identity/ending, balance, available balance, type, credit limit/APY and payment metadata | Only saved values; no live refresh implied; canonical bank balance preferred over mirrored card |
| Loans/payments | Role, lender/borrower notes, balance, principal, rate/type, payment frequency/amount, dates/term/status, payment history | Stored monthly payment is not verified minimum due; no new amortization forecast query |
| Transactions | Merchant, company, account, date, amount/currency, effective flow/category, pending status, correction notes, links | Uses TransactionIntelligence and all transaction pages already loaded; duplicate reconciliation and user classifications apply |
| Expense reviews | Decision, allocation category/purpose/notes, business amount, missing requirements, receipt count, source transaction | Owner session marker plus authorized source; receipt queries inspect actual missing requirements |
| Expense configuration | Analysis enabled/excluded accounts, business profiles, latest scan status/counts/period | Only after authenticated owner-specific loading |
| Documents | Metadata, notes, expiry/renewal metadata; extracted PDF/image text with pages | Existing on-device OCR: 25 MB file limit, first 100 PDF pages and 40,000 characters/page; index status exposes partial/unavailable files. Detail excerpts bounded to 6,000 characters |
| Obligations | Title, summary, state, severity, due/snooze dates, underlying source | Authorized underlying record required; archived/completed states searchable |
| Notifications/activity | Owned title/message/status/date | Loaded history; failures surfaced, not silently presented as complete |
| Sharing | Current user's resource access, role and shared-by display name | Not an organization-wide directory or complete invitation audit |
| Preferences/alerts | Loaded notification/briefing settings and configured alert fields | Not a general device-settings assistant; transient UI state and private auth/account internals are excluded |
| Passwords/security | Local account lookup and existing reveal/copy actions | Passwords, full account/routing/card numbers, authentication factors and recognized secrets are excluded from AI/Siri evidence |

All results are derived from an authorized current-session index. Data availability is described as **loaded records**, never lifetime bank history. Existing API response limits for nontransaction tables and retention imposed by the upstream service still apply. Missing historical balances cannot be reconstructed from current balances.

## Query contract

`PortfolioQueryEngine.swift` defines the allowlisted operations:

- `search`, `details`, `related`
- `largest`, `smallest`, `newest`, `oldest`, with top-N and ties
- `sum`, `count`, `average`
- `compare` current/selected period against the preceding period

Filters include record kind, bill/subscription type, exact company, inclusive ISO dates, transaction flow, pending inclusion, transfer exclusion, amount bounds, missing receipts, and an authorized source link. Grouping supports company, merchant, category, account, month and service type. UI filters cannot be overridden by assistant interpretation.

Calendar-month comparisons use the preceding calendar month. Explicit date ranges compare the preceding equal-length interval. An in-progress period is identified as potentially incomplete. Absence of a group means no loaded matching records, not a verified zero in the bank.

Calculations happen before pagination. Different currencies and transaction flows are not netted together. Unknown amounts are excluded with a partial-result explanation. Default transaction calculations exclude pending and ignored rows; explicit requests may include them. Largest transaction considers all remaining flows; largest expense applies the expense filter. Bills/subscriptions use active monthly equivalents unless asking about saved upcoming due dates; these are not historical charges or a future recurrence forecast.

Record evidence is paginated at 12 items, with independently bounded calculations/totals and source references. The four-search assistant budget is retained; a maximum/total does not require downloading every page into the model. Detailed notes and long metadata are requested on demand. Known stored secrets and recognized labelled secrets are redacted; arbitrary unknown, unlabelled secrets in free text cannot be guaranteed detectable.

## Regression and release verification

Automated tests cover old search behavior and the new engine, including:

- An older largest transaction beyond 1,000 records; ties, currencies and pending exclusion.
- Bills versus subscriptions, mixed add-ons, manual classification changes and index invalidation.
- Average/count, grouped totals, calendar boundaries, month comparisons and follow-up scope.
- Date and amount validation, conflicting UI filters, inaccessible sources, owner/session checks.
- Related-card service totals, missing receipts, bounded evidence pagination and preserved full totals.
- Native sheet rendering including the calculated answer, accessibility text, first open and empty results.
- Siri's session checks and actual Gemini Live `FunctionResponse` encoding.

The opt-in `testAuthenticatedTextAndLiveQueryToolsWhenOptedIn` uses synthetic records to check real Gemini planning, text answers, tool execution and spoken output. Use the normal signed simulator build, enable `MILOOM_QUERY_INTEGRATION=1` in the test runner and sign into that simulator app. `MILOOM_QUERY_WAIT_FOR_SIGN_IN=1` optionally allows UI sign-in during the test; credentials are never test inputs. Unsigned builds cannot reliably retrieve the Keychain session. It does not use user financial records. A skipped test is **not** verification of model behavior.

Actual Siri invocation, cold/locked-device behavior, physical-device responsiveness/VoiceOver, and broader model evaluation across representative questions remain required before calling the entire product feature release-complete. The implementation uses the installed iOS 26.4 SDK and retains iOS 17 compatibility; iOS 27-specific Siri behavior is not claimed.

## Verified runs — September 17, 2026

- Full iOS 26.4 suite: 171 tests, 4 opt-in skips, zero failures (`/private/tmp/miloom-query-upgrade-polish26.log`).
- Final retrieval/search suite on iOS 26.4: 38 tests, 1 opt-in skip, zero failures (`/private/tmp/miloom-query-final26.log`).
- Retrieval/search suite on iOS 17.5: 38 tests, 1 opt-in skip, zero failures (`/private/tmp/miloom-query-final-ios17.log`). This preceded the final explicit merchant/company fields in calculation evidence.
- Inspected six synthetic search render states, including calculated answers and large accessibility text. Final calculation layout is captured in `/private/tmp/miloom-query-polish-images`.
- Implementation branch: `feature/universal-search`; only native iOS files changed. No signing configuration or entitlements were edited; normal simulator signing was used for authenticated verification.
- Authenticated Gemini integration: **passed**, no skips (`/private/tmp/miloom-query-integration-final-verified.log`). Verified real REST query planning, the $85 bill-only answer (excluding the $20 subscription), Live tool execution, audible output, and the Archive transaction at $1,400. All evidence was synthetic. An earlier Live run omitted the merchant; explicit merchant/company fields and clearer instructions corrected the tested response. This is one integration scenario, not a guarantee of all model responses.


## Siri phrase recognition follow-up

The device reported unsupported Siri requests and offered other banking apps. Inspection found that the prior simulator build included `extract.actionsdata` with the correct actions and phrase templates, but no compiled App Shortcuts phrase catalog or SSU phrase assets. This is a concrete build gap; the screenshots alone do not establish the installed phone version or prove it is the only cause.

Added `Zifr/AppShortcuts.xcstrings` to the app's Resources build phase with the four existing English trigger phrases. This enables `AppShortcutsStringsMetadata` and `AppIntentsSSUTraining`. Verified that the build now includes `en.lproj/AppShortcuts.strings` and `Metadata.appintents/root.ssu.yaml`, and the training log identifies Miloom and both actions. No entitlement, signing, minimum OS, credential handling, or query behavior changed.

Verification: Xcode 26.4 iPhone 17 Pro simulator build succeeded; `/private/tmp/miloom-siri-catalog-build.log`. Actual voice recognition on the user's physical phone remains unverified. Install this branch's new build on the phone, launch it once, confirm Ask Miloom and Search Miloom are discoverable in Shortcuts, then test Siri's exact trigger before entering the question. “Ask Miloom how much money is in my 401k” is not a registered free-form single-utterance template.

## Grouped search overviews — September 17, 2026

Generic institution and service matches now lead with a scoped overview card. Credentials and website actions precede saved balances or recurring prices; native disclosure controls hold subservice details, linked transaction history and documents. Naming a subservice promotes and expands it inside its parent. Other matching records remain below the overview. Explicit transaction/calculation/date/type filters and numeric lookups retain the precise result list.

`SearchOverview` assembles authorized index records using saved parent IDs, financial identities and confirmed connections. It does not merge same-brand owners, guess service transactions from every charge on a funding card, or double-count mirrored card/account balances. Parent costs and active add-ons each contribute once; non-monthly billing is labeled as a monthly equivalent. Child payment methods override inherited parent funding. Separate saved card logins remain accessible even when their balances are grouped under a bank.

Search artwork uses saved company logos, service/bank website favicons and transaction merchant artwork/websites, with a small known-brand fallback catalog. Missing artwork uses initials. Logo and navigation metadata are omitted from assistant evidence; password access remains local with the existing direct reveal/copy controls. No new Gemini calls, dependencies, deployment-target changes or backend contracts were added.

Coverage limits: the overview shows only saved financial/document/history relationships and the current user's known access role. The current schema does not provide a complete outgoing sharing roster, vehicle identity hierarchy or separate embedded-subservice credentials, so those illustrative design fields are not invented. Billing dates/amounts are saved schedule data, not verified upcoming invoices. The UI uses the installed iOS 26.4 SDK and existing native material controls while retaining iOS 17 support.

Verification: simulator build succeeded; initial focused runs on iOS 26.4 and 17.5 each executed 44 tests (one optional metered Gemini integration skip, zero failures). Synthetic sheet screenshots cover bank/service overviews, generic Tesla, expanded Tesla Insurance, exact endings, calculated answers, empty states and accessibility text. Final verification and device acceptance are recorded in the shared project handoff. Physical Siri acceptance remains separate and unchanged.

Final focused verification: `/private/tmp/miloom-overview-final26.log` and `/private/tmp/miloom-overview-final17.log` each passed 43 tests with one optional Gemini integration skip (44 executed, zero failures). The combined multi-destination runner stalled after its first destination and was terminated; the separate runs completed successfully. The last login-wrapping adjustment passed the iOS 26.4 render test, `/private/tmp/miloom-overview-layout-final.log`; nine final UI states are in `/private/tmp/miloom-overview-layout-images`. Inspected the Tesla, bank and large-text layouts. Physical-device VoiceOver/touch acceptance and the prior Siri release checks remain open.

## Search card refinement — September 18, 2026

Removed the Best matches heading and result counts. Saved pricing and renewal dates now sit beneath the service name, with a light-grey website icon beside the name. Shared credential boxes keep the login visible; tapping a box copies its current authorized value with a checkmark, temporary Copied highlight, accessibility announcement and success haptic. The password eye alone toggles visibility; copying does not reveal it. Revealed values clear when the app/session/record changes. No Face ID requirement was added. The same controls are used by service, financial and saved-login search results.

Service Charge history now combines saved links with unambiguous merchant-name/domain matches in the same authorized company. Known payment-account matches constrain assignment; duplicate service accounts remain separate when ambiguous. Specific child names can match child histories, while a generic parent merchant is not assigned to every add-on. Income, transfers and ignored rows are excluded from inferred charge history. Matching transactions are removed from More matches and pagination accounts for the remaining rows. This is local presentation only: it does not create confirmed links or alter Gemini/Siri query relationships. Historical charges with incompatible known funding accounts may remain in More matches. This supersedes the September 17 linked-only service-history limitation.

Verification: focused suites on iOS 26.4 and 17.5 each passed 46 tests with one optional Gemini integration skip (47 executed, zero failures), using normal signed simulator builds. Logs: `/private/tmp/miloom-search-fields-final26.log` and `/private/tmp/miloom-search-fields-final17.log`. Added regression coverage for clipboard/reveal independence, current values and revoked access; company/account scoping and ambiguity; and parent/child merchant histories. Exported nine synthetic layout states to `/private/tmp/miloom-search-fields-final-images`; inspected service, expanded child and large-text layouts across the refinement runs. The updated iPhone 17 Pro simulator app was launched. Physical-device haptics/VoiceOver and acceptance with the user's real saved records remain unverified. No new paid model call, backend change or deployment was required.


## Actual billing periods and aligned headers — September 18, 2026

Search headers now align their logo/name/pricing with service cards. Grouped services show separate actual-cycle totals (for example $668 /mo and $120 /yr) with gold period suffixes and a divider, rather than a monthly equivalent. Amounts remain separated by currency, paid active components count once, and paused components are excluded. This replaces the September 17 monthly-equivalent overview presentation; the calculation/query engine remains unchanged. The gold Paid with row now sits below pricing, followed by Next payment. Shared search-card secondary text increased by one default-size point with Dynamic Type preserved; narrow/large-text layouts stack the billing totals.

Verification: focused suites on iOS 26.4 and 17.5 each passed 46 tests with one optional Gemini integration skip (47 executed, zero failures): `/private/tmp/miloom-search-billing26.log` and `/private/tmp/miloom-search-billing17.log`. The existing service grouping regression now asserts separate monthly/yearly totals and suffixes. The synthetic Tesla screenshot uses $668 monthly plus $120 yearly. Ten rendered states include mixed billing at accessibility size. Visual inspection caught a large-text overlap; intrinsic-height modifiers corrected it and the final iOS 26.4 render test passed (`/private/tmp/miloom-search-billing-spacing26.log`). Final screenshots: `/private/tmp/miloom-search-billing-spacing-images`. The iOS 17 suite preceded only that final layout-height adjustment. Physical-device acceptance remains open. No commit, backend change, deployment or new model call.


## Typing responsiveness — September 19, 2026

Fixed a quadratic UI path: the grouped-history ID set was rebuilt inside every hit-filter predicate, repeatedly during each body evaluation. SearchResultPage now builds it once per render and stops after enough ungrouped rows to fill the page. Card identities remain stable while text changes; matching subservice expansion updates explicitly. Payment-source projections are prepared with the background results rather than scanning the whole index per visible row. Merchant history is skipped when no service overview is needed. Cancellation propagates to detached query work and ranking/history loops cooperate; stale query/session results cannot publish.

Cold or invalidated indexes now build from an immutable Sendable snapshot off the main actor. One pending build is reused for successive keystrokes in the same user/revision; the cache accepts only the matching current session/revision and clears pending work on logout. The existing synchronous projection API still serves other callers and local credential actions. Assistant query execution from the search sheet also uses background work. There is no change to ranking, billing amounts, permissions, AI evidence, or the 100 ms typing debounce.

Verification: focused search suites on iOS 26.4 and 17.5 each passed 50 tests, with one optional Gemini integration skipped (51 executed, zero failures). Logs: `/private/tmp/miloom-search-lag-final26.log` and `/private/tmp/miloom-search-lag-final17.log`. New regressions cover 10,000-hit grouping/pagination, cancelled queries, background/synchronous projection equivalence and session clearing, plus repeated search-binding updates in a rendered sheet with 10,000 charges and a cold index. Grouped-page p95 was 4.45 ms / 4.78 ms; worst main-actor scheduling delay during the typing scenario was 33.85 ms / 21.38 ms (iOS 26.4 / 17.5). These are synthetic simulator scheduling measurements, not physical keyboard-to-screen latency or a device frame-rate guarantee. Existing ten-state render and retrieval/security regressions passed. No live Gemini/Siri verification was repeated; physical-device typing acceptance remains open. Changes are uncommitted.
