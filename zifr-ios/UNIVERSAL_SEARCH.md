# Universal search implementation handoff

Branch: `feature/universal-search`

Base: `db1c2331a0fe17aac24088c2db9026cd3cdc1f4f`

Worktree: `.worktrees/universal-search` under the original repository.

Scope: native `zifr-ios` only. This handoff accompanies the universal-search implementation.

## Implemented behavior

- One authorized, session-bound search projection is used by in-app search and Gemini's `searchPortfolio` tool. Search caches are invalidated by edits, deletions, reassignment, sharing changes, document extraction and session changes.
- Search includes companies; services, supplemental-service names, linked emails and notes; cards; individual bank accounts; loans and their payments; loaded Plaid transactions and local classifications; documents and extracted pages; active obligations; confirmed resource connections.
- Exact card/account endings rank first. Duplicate endings remain separate records with company names. Relationships use saved identifiers; legacy names link only when unique within the same company. Numeric identifiers are never typo-matched.
- Text matching supports case/diacritic folding, prefixes and single-edit/transposition typos. Company, type and calendar-period filters are visible. Search is debounced and the matching/sorting work runs away from the main actor.
- Result cards show identity, company, match reason, saved balance/available funds, actual billing cycle or transaction date, relevant excerpts and visible actions. Card/account results offer linked Services and Transactions. Transactions open their detail in the transaction center; bank accounts open their owning institution; loan payments open their owning loan/ledger. Document-content results open the numbered page.
- Deterministic transaction totals separate currencies and flows, and exclude pending, transfer and ignored records. Totals use every matching record, before visible-result pagination. Recurring-cost queries normalize supported billing cycles and active add-ons, exclude cancelled/paused services and flag unknown cycles. `subscription spend per company` produces separate company totals.
- Financial queries such as `Citi balance`, `Chase bank balances`, `credit card balances`, `how much do I owe`, `available balances`, `Citi APR` and `Citi monthly payment` retrieve the numeric facts directly. Cash, investments, credit debt, loan debt and receivables stay separate, as do currencies and optionally companies. Durable account/card identifiers deduplicate totals; bank account values take precedence over mirrored card values in totals. Differing saved card and linked bank balances are disclosed in evidence. Historical balance snapshots are not available. Unknown available balances are excluded and partial totals are labelled.
- Document PDF text and scanned-image OCR are extracted on device. Indexing runs for authorized loaded documents and can be retried from Search. Extracted content is session-only. Downloads use an ephemeral URLSession; extraction is bounded to 25 MiB/file, 100 PDF pages and 40,000 characters/page. Partial/unavailable coverage is reported. Unsupported files, locked PDFs and missing files remain searchable by metadata.
- Failed portfolio reads are disclosed by data category. Account changes and cancelled fetches cannot publish an older search session's results.

## Search sheet design

- Search keeps native keyboard dismissal on submit and immediate dismissal when scrolling results. The toolbar contains only Close; the keyboard, Ask, and info icons were removed at the owner’s request.
- Uses the app's existing charcoal (`zifrCard`) and gold (`zifrGold`/`miloomGold`) palette. Liquid Glass is restricted to navigation/search controls and filter capsules; content rows use quieter solid surfaces. The sheet uses regular system material, with system-managed corner geometry.
- Best matches and related records have distinct sections. Saved balances and available funds remain visible. Login, service/transaction navigation, and direct password reveal/copy remain accessible from result rows.
- The search toolbar contains only Close. Gemini remains available through the app’s assistant; refresh issues remain visible in results.
- One child-sheet route handles records, saved logins, coverage, and upgrades. Its presenter is attached to the content inside the navigation stack. Attaching it to the outer navigation shell reproduced an iOS 17 presentation loop; the content anchor passes the real-sheet rendering check.
- Uses semantic Dynamic Type fonts, 44-point action targets, vertically stacked password controls for accessibility text sizes, system separators, and a solid filter fallback for Reduce Transparency. Company, Type, and Date filters share the available width without horizontal scrolling, and stack at accessibility text sizes. Reset appears on a separate row when needed.
- Design references: [Apple materials HIG](https://developer.apple.com/design/human-interface-guidelines/materials), [sheets HIG](https://developer.apple.com/design/human-interface-guidelines/sheets), [native search](https://developer.apple.com/documentation/swiftui/adding-a-search-interface-to-your-app), and [adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
- Installed tooling remains Xcode 26.4. Native Liquid Glass APIs are used where supported, with an iOS 17 fallback. No iOS 27-specific APIs or iOS 27 runtime verification are claimed.

## Credentials

- Passwords, full card/account/routing numbers and recognized labelled secrets are omitted/redacted from the search projection. Credential records expose availability and identity, not password values.
- At the owner's request, passwords reveal or copy immediately without Face ID/Touch ID/passcode prompts. Search has inline Reveal/Hide and Copy password actions. Services, banks, financial cards and edit forms use the original one-tap eye controls. Context menus copy directly.
- Revealed values hide when leaving the foreground or view. Clipboard copies remain local-only and expire after 60 seconds. The current session, record existence and access are checked when resolving a search password; already-unreadable encrypted values remain unavailable.
- Ambiguous assistant requests still open a local account picker, with direct reveal/copy controls. Gemini receives only completion status, never the credential value. Voice capture pauses during the picker.
- Flipping a financial card no longer launches authentication or blocks password access. The pre-existing authentication for its full card number is now a separate explicit action. App sign-in/device-lock behavior is unchanged. Raw-password sharing and speech are not reintroduced.
- Arbitrary free-form text cannot be guaranteed to contain no unlabelled unknown secret. Known saved values, labelled credentials and long card-number-like strings are redacted. No raw document text or credential values are logged by the new code.

## Apple and Gemini integration

- iOS 17 remains the deployment minimum.
- A discoverable App Shortcut opens Search with the requested query. The iOS 18+ system search intent uses Apple's existing search schema. Both require local device authentication and preserve a pending query through app loading/sign-in.
- iOS 26+ Foundation Models are used only when available. An explicit **Ask on device** action can translate a natural-language question into the same search syntax and summarize retrieved evidence.
- **Ask Gemini** is explicit and uses the existing access/usage gate and server proxy. No Gemini calls happen while typing. A complex question can require a query rewrite plus an answer request. Text/live assistants request bounded evidence instead of receiving the entire portfolio in their system prompt; retrieval rounds are capped at four per question.
- AI receives bounded source IDs, titles, company names, details, safe document excerpts, allowlisted financial facts (balances, available funds/credit, limits, APR/APY, principal, monthly payment, due/renewal dates), currency, bank sync/connection status and precomputed totals. Card and loan records have no currency field, so their app-default USD basis is identified unless an explicit card-account link supplies currency. Gemini Live and text instructions require answering the requested numbers directly instead of sending the user to open a card. `searchPortfolio` supports bounded 12-record pages via `offset`/`nextOffset`; totals cover all matches, with sampled source IDs. Search results remain visible. Model instructions prohibit inventing facts or recomputing totals; factual answer quality still needs live-model evaluation.
- Private portfolio data is not donated to the system Spotlight index. No new entitlements, dependencies, signing changes, deployment-target changes or backend contracts were introduced.

## Verification completed

- Final app builds with Xcode 26.4 for the simulator, retaining the iOS 17 deployment minimum.
- Before the presentation redesign, the complete iPhone 17 Pro / iOS 26.4 functionality suite had **157 tests executed, 3 existing opt-in Gemini integration tests skipped, zero failures**. The focused search suite was rerun after the redesign.
- Final search suite: **24 tests passed** on iOS 26.4. Tests cover exact identifiers, permissions, credentials and current-session checks, financial facts through the actual Gemini Live FunctionResponse encoding, monetary precision, bank/card deduplication, currencies, cash/debt/receivables, unavailable balances, historical-balance limitations, full totals across paginated evidence, cache freshness, monthly cost/transaction totals, PDF/image OCR, source navigation, rendering and large-index performance.
- Final iPhone 15 Pro / iOS 17.5 search suite: **24 tests passed, zero failures**.
- The rendering check now presents a real system sheet and captures five fixture states: exact `4242` matches, a service with password actions, accessibility text, no results, and first open. Fixture captures are exported for visual review; they contain no user credentials.
- Warm exact-ending search still passes the 10,000-record simulator performance regression check. This excludes index construction and is not a physical-device latency claim.
- `git diff --check` passes. All implementation changes are scoped to native `zifr-ios`; see Git history for commit status.

Current verification logs:

- `/private/tmp/miloom-financial-search-final-tests.log` — full functionality suite before the presentation redesign
- `/private/tmp/miloom-search-redesign-verified26.log` — 24 tests, including all five final rendering states, on iOS 26.4
- `/private/tmp/miloom-search-redesign-verified17.log` — 24 tests, including all five final rendering states, on iOS 17.5
- Final fixture screenshots: `/private/tmp/miloom-search-verified26` and `/private/tmp/miloom-search-verified17`.

Presentation changes in this iteration are limited to `GlobalSearchView.swift`, the shared password action styling in `CredentialSearchSheet.swift`, the existing render test in `UniversalSearchTests.swift`, and this handoff. No search-engine, backend, dependency, or deployment-target changes were required.

## Release gates still open

This branch is implemented for review; the entire originally discussed feature is **not yet release-complete**.

1. Test the cold/warm Siri handoff on a real device, including a locked device, signed-out state and an already-presented modal.
2. Check direct password reveal/copy, background hiding, clipboard expiry/paste into another app, and access revocation on a real device. Password actions no longer request Face ID. Full-card-number authentication is a separate existing feature.
3. Evaluate on-device Apple answers and authenticated Gemini text/live answers against representative user questions, source identity, refusal/unavailable/quota states, voice pause/resume and actual metered costs. The three existing opt-in Gemini integration tests were not run.
4. Run VoiceOver, large Dynamic Type and physical-device p95/index-build performance checks against a realistic portfolio and mixed PDF/scanned documents.
5. iOS 27-specific search/Spotlight tools and Private Cloud Compute are **not implemented**. Only Xcode 26.4 is installed here. Adopting those APIs requires an iOS 27 SDK/device; Private Cloud Compute would additionally need approved entitlement/access changes. Existing App Intents and iOS 26 on-device functionality are already available without raising the app's minimum OS.
6. Offline search covers records already loaded in this app session. The app has no durable offline portfolio cache; this change does not add one. Search cannot claim full coverage for unavailable bank history or unsupported/unloaded document contents.


## Retrieval and calculation upgrade — September 17

See [the data inventory and query contract](SEARCH_RETRIEVAL_COVERAGE.md) for current capabilities and limits. `PortfolioQueryEngine` now serves Search, Gemini text/Live and native Siri queries. It separates bill/subscription classifications and add-on costs, adds full-result ranking/aggregation/comparisons, validates scopes and dates, supports source details/relationships, and expands coverage to expense reviews, notifications, activity, preferences and alert rules.

The current search toolbar remains Close-only. Bills and Subscriptions have separate Type choices. Questions receive native calculation cards; unresolved submitted questions can use Gemini interpretation without restoring the removed toolbar icons. The earlier references above to toolbar Ask/info actions describe historical iterations.

`AskMiloomIntent` can return a shared-engine answer; `ReadMiloomRecordIntent` exposes authorized App Entities. Financial records are not donated to Spotlight. Siri returns an open/unlock fallback if the app session is not ready. Device-level Siri behavior still needs physical-device verification.

Verification logs for this iteration are recorded in `SEARCH_RETRIEVAL_COVERAGE.md`: full simulator suite, iOS 17.5/26.4 search suites, and a passing authenticated Gemini text/Live synthetic-data scenario. Historical test counts above refer to their original builds. Broader model and physical Siri/VoiceOver checks remain open.
