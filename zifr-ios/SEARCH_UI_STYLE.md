# Miloom Search Overview Style

Status: implemented native iOS reference style

Reference commits: `79e4f129`, `d579648f`
Primary implementation: `Zifr/Views/Search/SearchOverviewCard.swift`

## Recall this style

Use this phrase in a future task:

> Use the Miloom Search Overview Style from `zifr-ios/SEARCH_UI_STYLE.md`.

For a broader app screen, say:

> Apply the Miloom Search Overview Style and reuse the existing design-system components. Preserve native iOS behavior, Dynamic Type, and accessibility.

This document names the visual language. The current SwiftUI implementation and tests remain the source of truth when this description and the code differ.

## Design intent

The Search Overview Style is a dark, compact, native iOS presentation for services, bills, subscriptions, banks, and their related financial records. It uses clear content hierarchy, neutral charcoal surfaces, white primary information, Miloom gold for financial context and actions, and green status indicators.

Use native SwiftUI interaction patterns. Controls must have at least a 44-point target, support Dynamic Type, preserve Reduce Motion behavior, and use right-facing disclosure chevrons when closed and downward chevrons when open.

## Card anatomy

Each matched entity has its own section. The uppercase `ENTITY • SERVICE` or `ENTITY • BANK` label sits outside the card.

The outer card uses:

- charcoal surface: `Color(white: 0.075)`
- continuous rounded shape, 26-point corner radius
- 16-point internal padding
- generous vertical separation between the header, credentials, rows, and disclosures

The inset header uses:

- black surface
- 20-point corner radius
- 14-point padding
- 48-point brand logo
- white title and amounts
- Miloom gold billing suffixes and supporting financial text
- a 44-point website action beside the title when a valid site exists

The title aligns with the top of the logo. The primary amount aligns with the lower portion of the logo. Supporting schedule or aggregate information follows beneath it.

## Header variants

### Standalone bill or subscription

Use this when the saved service has no subservices:

1. Brand logo and service name
2. Saved billing amount and native billing period
3. Gold schedule text, for example `Due 30th every month • Auto pay on`

Do not show aggregate bill, subscription, or payment-source counts. Do not repeat the same service as a second row beneath the header. A free standalone service shows `Free` without a meaningless schedule.

### Service with subservices

Use this when the parent contains one or more subservices:

1. Brand logo and parent name
2. Separate active billing totals for each saved cycle and currency
3. Aggregate counts formatted as `2 Bills | 2 Subscriptions | 1 Payment source`

Numbers are white. `Bills`, `Subscriptions`, and `Payment source(s)` are gold. Use vertical bars as separators. The base service appears in the breakdown only when it has its own paid charge.

### Bank or institution

Use the same header surface and alignment. Show `Accounts | Cards | Loans`, with white numbers, gold labels, and vertical-bar separators. Keep distinct entities in distinct cards even when their saved bank names match.

## Credentials

The credential treatment follows `SINGLE.jpg` and is implemented by `SearchCredentialBoxes`:

- uppercase gray `LOGIN ID` and `PASSWORD` labels
- neutral rounded fields with a 14-point radius
- eye control inside the password field
- horizontal fields at standard text sizes and stacked fields at accessibility sizes
- tap-to-copy, copied feedback, reveal/hide, privacy handling, and existing authorization checks

## Payment sources and service rows

Payment-source rows use Miloom gold and show the issuing bank logo when a trusted institution relationship can be resolved. Keep the actual saved card or account name and ending in the label, such as `Paid with: Visa ••9225`.

Use each base/subservice's resolved saved payment source for its row and charge matching. General saved connections must not add an older or child-only source to that row. The grouped header still counts distinct sources across all active rows; KIA can legitimately have two sources in the header while its base shows only checking and Premium Connectivity shows only Citi.

For grouped services, indent the compact facts beneath the payment-source text so the visual hierarchy remains attached to that bank or account:

- relative due date
- auto-pay status
- latest confidently attributed posted expense, when available
- `Active since [date]` and elapsed months, when transaction history is available
- conservatively observed charge increases, only when enough history exists

Funding coverage belongs in the Brief and does not appear in Search cards. Grouped rows omit unavailable-history placeholders and `Not enough history`. Pending charges, refunds, transfers, ignored transactions, currency mismatches, gaps, ambiguous periods, and uncertain service assignments must not establish historical facts.

Base-service and subservice rows share one layout:

- service logo with the name top-aligned beside it and a smaller italic gray service type directly below the name
- white amount followed by the saved cadence and due day, such as `$283 /monthly on the 30th`
- payment-source action with bank logo and text matching the indented fact-list size
- the same indented fact list
- saved purpose when present

The logo/name stack opens the service sheet. The separate trailing chevron controls the row's transaction accordion. Separate service rows with subtle divider lines.

When a generic parent-brand transaction uses the same entity, currency, and precise card/account as one service row, Search may assign it to that row when its posted amount is either exact or uniquely within two percent of the saved estimate. This presentation-only inference can supply transaction history and the next billing day; it does not persist a relationship or rewrite the saved service. Exact and explicit relationships remain authoritative, and ambiguous candidates stay in account-wide history.

## Accordions

Accordions expand downward in place. The closed state uses `chevron.right`; the open state uses `chevron.down`. Expansion state is independent for each row or card.

Past transactions start closed, show the latest three when opened, and expose a `More` action when additional loaded transactions exist. Account-wide unmatched history remains separate from confidently attributed service history. More Matches transactions are grouped into independent year accordions.

## Existing design-system foundation

Miloom already has reusable foundations:

- Brand colors and borders: `Zifr/Extensions/Color+Zifr.swift`
- Card and material modifiers: `Zifr/Extensions/View+Glass.swift`
- Buttons, list cards, accordion, and disclosure chevron: `Zifr/Views/Components/SharedComponents.swift`
- Search card components: `Zifr/Views/Search/SearchOverviewCard.swift`
- Credential component: `Zifr/Views/Search/CredentialSearchSheet.swift`
- Search-sheet structure: `Zifr/Views/Search/GlobalSearchView.swift`

This is a partial design system. Colors and several components are centralized, but spacing, typography, shapes, and entity headers are not yet represented by a complete semantic token layer. Some feature views still own raw font sizes, padding, radii, surfaces, and disclosure treatments.

## How to extend it

Treat this Search style as the reference implementation while building the broader Miloom design system.

1. Reuse an existing shared component or semantic color before adding a local visual rule.
2. When the same visual decision appears in a second feature, extract a semantic token or component such as `MiloomSpacing.card`, `MiloomRadius.card`, or `MiloomEntityHeader`.
3. Name tokens by purpose rather than their numeric value.
4. Keep screens responsible for content and state; shared components determine appearance.
5. Migrate existing screens incrementally as they are touched. Avoid a single app-wide visual rewrite.
6. Preserve native `Menu`, sheet, navigation, accessibility, and disclosure behavior instead of replacing them with desktop-style custom controls.

The highest-value next shared components are `MiloomCard`, `MiloomEntityHeader`, `MiloomAmount`, `MiloomDisclosureRow`, and semantic spacing, radius, and typography tokens. The current Search components should be adapted into those shared components only when another feature is ready to use them, so extraction is driven by real reuse rather than speculative abstraction.

## Verification reference

`UniversalSearchTests.testSearchScreenRendersExactMatchesAndRelatedActions` renders standard and accessibility fixtures for standalone bills, standalone subscriptions, grouped services, banks, credentials, filters, histories, and calculated results. Use those fixtures when changing this style.

The design must continue to preserve:

- separate cards for identical brands owned by different entities
- standalone versus grouped header rules
- mixed billing cycles and currencies
- bank-logo payment-source identity
- Dynamic Type layouts
- credential protections and actions
- independent accordion state
- transaction attribution and navigation
