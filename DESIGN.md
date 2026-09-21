---
name: Cifr Entrepreneur Manager
colors:
  primary: "#223e5a"
  secondary: "#227b5f"
  tertiary: "#545454"
  text-muted: "#A2A2A2"
  background: "#000000"
  surface: "#171717"
  surface-dim: "#111111"
  surface-glass: "rgba(28, 28, 30, 0.6)"
  on-surface: "#ffffff"
  on-surface-variant: "rgba(255, 255, 255, 0.35)"
  outline: "rgba(255, 255, 255, 0.08)"
  outline-variant: "rgba(255, 255, 255, 0.05)"
  error: "#911c26"
  warning: "#b29b62"
typography:
  label-sm:
    fontFamily: System
    fontSize: 10px
    fontWeight: "600"
    letterSpacing: 0.3px
    textTransform: uppercase
  label-md:
    fontFamily: System
    fontSize: 11px
    fontWeight: "600"
    letterSpacing: 0.3px
    textTransform: uppercase
  label-heavy:
    fontFamily: System
    fontSize: 12px
    fontWeight: "900"
    letterSpacing: 1px
    textTransform: uppercase
  body-sm:
    fontFamily: System
    fontSize: 12px
    fontWeight: "500"
  body-md:
    fontFamily: System
    fontSize: 13px
    fontWeight: "500"
  body-lg:
    fontFamily: System
    fontSize: 14px
    fontWeight: "600"
  heading-sm:
    fontFamily: System
    fontSize: 16px
    fontWeight: "700"
  heading-md:
    fontFamily: System
    fontSize: 18px
    fontWeight: "600"
rounded:
  sm: 8px
  md: 10px
  lg: 14px
  xl: 24px
  pill: 999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 20px
components:
  glass-card:
    backgroundColor: "{colors.surface-glass}"
    rounded: "{rounded.xl}"
    outline: "1px solid {colors.outline-variant}"
  liquid-glass-button:
    backgroundColor: "{colors.primary}"
    rounded: "{rounded.pill}"
    padding: "8px 16px"
  input-field:
    backgroundColor: "{colors.surface-dim}"
    rounded: "{rounded.lg}"
    outline: "1px solid rgba(255, 255, 255, 0.1)"
    padding: "12px 16px"
  compact-input:
    backgroundColor: "rgba(0, 0, 0, 0.4)"
    rounded: "{rounded.sm}"
    outline: "1px solid {colors.outline-variant}"
    padding: "10px 12px"
---

## Brand & Style
Cifr is a dark-mode native, high-density entrepreneur's company manager designed with strict adherence to modern mobile paradigms. The aesthetic is "Pro" and unapologetically data-centric, utilizing deep blacks, subtle greys, and elegant blue and green accents to create a hierarchy that feels instantly responsive and professional. It embraces a "glass-over-darkness" philosophy, contrasting stark black backgrounds with elevated glass cards to define spatial relationships without visual clutter.

## Colors
The color strategy relies on maximum contrast on a pure black canvas to minimize eye strain while ensuring absolute clarity of financial and operational data.

- **Primary Canvas:** Pure Black serves as the infinite void, allowing data to be the primary focus.
- **Surfaces:** Dark greys are used to elevate cards and group information.
- **Accents:** An elegant green, a deep blue, and a soft grey are used sparingly for status indicators, active states, and effortless information presentation.
- **Borders & Separators:** Almost invisible white opacities (5% to 10%) are used to draw hard edges without introducing solid, distracting lines.

## Typography
Typography is system-native, prioritized for extreme legibility in compact, high-density layouts.

- **Micro-Labels:** Heavy, wide-tracking uppercase labels (10pt-12pt) are used as section headers, field descriptors, and primary action buttons. They sit quietly in the background using muted opacities or punch out with extreme weights.
- **Data Values:** Inputs and copyable values use medium to bold weights at 13pt-16pt, appearing in solid white to punch out from the dark background.
- **Headings:** High-fidelity numbers and entity names utilize larger sizes (16pt-18pt) with tight tracking to ensure visual balance.
- **Hierarchy:** Font weight is used far more aggressively than size to establish hierarchy in tight spaces.

## Elevation & Depth
Depth is created through subtle layering of dark materials and native blurs, rather than traditional drop shadows which get lost on black backgrounds.

- **Level 0 (Background):** Pure black.
- **Level 1 (Cards & Modals):** Dark surface panels with a 5% white border to catch the "light".
- **Level 2 (Floating/Overlays):** Translucent frosted glass materials, adding delicate boundaries to physically separate elements from the base UI without entirely obstructing it.

## Layout & Motion
The layout champions extreme information density, focusing on smooth, gestural flow and spatial efficiency.

- **Radii:** A distinct corner radius hierarchy. Small internal elements (fields, buttons) use tighter curves, while main architectural cards use generous corner smoothing. Interactive elements often use full pill (capsule) shapes.
- **Liquid Glass:** Action buttons utilize an advanced "liquid glass" morphing animation. When interacted with, elements expand and seamlessly merge their geometric bounds with neighboring components, simulating viscous physics rather than rigid bounds.
- **Interactive Feedback:** Haptic feedback is a first-class citizen, paired with structural micro-animations on actions like expanding accordions, copying values, or revealing secure fields.

## Old Entity Sheet

> Legacy reference snapshot, saved 2026-09-20. “Old Entity Sheet” means the create-mode UI of `EditCompanySheet` (`company == nil`) as it existed when this snapshot was recorded. Preserve this description as a visual fallback when the entity-creation experience is redesigned; it is not the default direction for new screens.

### Presentation and structure

- Opens as a native SwiftUI sheet from the dashboard’s Add Entity action and contains a `NavigationStack` with a vertically scrolling form.
- Uses a solid `#1C1C1E` full-sheet background, 20pt horizontal page insets, 16pt top inset, 40pt bottom inset, and 20pt spacing between primary cards.
- The compact navigation bar reads **New Business** in 17pt bold gold (`#C1AA78`), with **Cancel** leading and **Save** trailing. Save is disabled until a business name exists and becomes green when enabled.
- The create flow has two stacked cards: **BUSINESS IDENTITY** followed by **APP NAVIGATION**. Edit-only connection, sharing, and deletion controls are not part of the old create-mode sheet.

### Card treatment

- Cards use the shared `ZifrSheetCard`: 24pt continuous corners, black at 70% over regular material, and a 1.5pt vertical gold border gradient from `#918457` to 30% opacity.
- Card headers use 12pt black-weight uppercase gold text (`#C1AA78`) with 1.5pt tracking, 20pt horizontal padding, 14pt vertical padding, and an 8% white divider.
- Card content uses 20pt horizontal padding, 16pt top padding, and 20pt bottom padding.

### Business Identity card

- A 70×70pt rounded identity tile sits beside the business-name field. It has an 18pt radius and 10% white outline. Without a logo it shows the selected brand color plus the first name initial in 28pt black-weight rounded type; when empty it shows `?`.
- Tapping the identity tile cycles through `Company.brandColors` with a spring animation and clears any uploaded logo. An uploaded logo fills and crops within the same tile and gains a red remove control at the top-right.
- **BUSINESS NAME** uses the shared premium field: 12pt regular uppercase label at 45% white; 44pt-high `#2C2C2E` input with a 10pt radius, 6% white outline, 12pt horizontal inset, and 14pt regular white value text. Placeholder: `Acme Holdings LLC`.
- **WEBSITE** repeats that field treatment with placeholder `acme.com`. A 72pt-wide adjacent upload tile uses `#2C2C2E`, a 12pt radius, 6% white outline, the `square.and.arrow.up` symbol, and a 9pt black-weight tracked **UPLOAD** label.
- **BUSINESS CATEGORY** is a 36pt-high two-option segmented control: Personal / Business. Its track is `#2C2C2E` with a 10pt radius; the selected 8pt-radius segment is Miloom gold with dark `#121212` text and moves with a 0.25-second ease-in-out matched-geometry animation.
- **BUSINESS STRUCTURE** is a 120pt-high wheel picker on `#2C2C2E`, with a 12pt radius and 6% white outline. Personal offers Household and Individual; Business offers the remaining company structures.

### App Navigation card

- A 52pt-high `#2C2C2E` row contains **Demo Account** in 14pt semibold white, supporting copy in 11pt regular at 50% white, and a green-tinted native toggle.
- A full-width **Replay Tutorial** action sits below it, with a play-circle icon, 14pt semibold white text, 12pt vertical padding, a green `#166A4E` fill, and a 12pt radius. Pressing scales the control to 97% over 0.2 seconds.

### Interaction signature

- Medium haptics accompany logo-color changes, demo toggling, and Save; Replay Tutorial uses a light haptic.
- Switching category or dragging the structure wheel dismisses the keyboard. The scroll view also dismisses it interactively, and tapping the sheet background resigns focus.
- Personal defaults to Individual; switching to Business selects LLC. Save persists name, structure, lowercase color hex, optional website, and optional logo.

### Implementation anchors

- Sheet and create-mode layout: `zifr-ios/Zifr/Views/Company/EditCompanySheet.swift`
- Shared card shell: `zifr-ios/Zifr/Views/Components/ZifrSheetCard.swift`
- Premium input, segmented control, and secondary button style: `zifr-ios/Zifr/Views/Components/SharedComponents.swift`
- Dashboard presentation entry point: `zifr-ios/Zifr/Views/Dashboard/DashboardView.swift`

## New Entity Sheet

> Current entity create/edit direction, implemented 2026-09-20. The old treatment above remains the named legacy reference; dashboard and entity-detail pencil actions now open `NewEntitySheet` in edit mode.

### Product flow

1. **Entity:** capture the required name plus optional logo/icon, Personal or Business category, and the corresponding profile/business type.
2. **Accounts:** keep the entity as an in-memory draft while strongly recommending at least one Plaid connection. The user may instead choose Set Up Later.
3. **Review:** after Plaid, show every returned account, preselect all of them, and let the user remove accounts before saving. Set Up Later uses a separate alternate Review—not a replacement for Plaid review—that offers an optional local Demo Account with sample app data and reminds the user that a real account can be connected later from the entity’s Financial tab.

The entity remains an in-memory draft when **Add Accounts** is pressed. It is committed only by **Save**, **Set Up Later**, or when a successfully completed Plaid Link session is ready to exchange its token and requires the draft’s stable entity ID. Set Up Later saves before presenting its alternate Review. A provisional entity created for a failed token exchange is removed. Successful completion opens the entity on its Financial tab.

### Visual system

- Native sheet with a grabber, compact inline title, leading Cancel/Close control, and a three-stage progress indicator. Entity, Accounts, and Review all use the same 84% detent, matching the reference composition; their scroll views preserve accessibility at larger text sizes. The progress glyphs stay fixed as building, link, and check across the flow. Accounts and Review present Back and Close as separate adjacent native toolbar buttons. Entity identity also exposes a trailing Save action that enables and turns green only after a valid change.
- Matches the legacy entity sheet’s `#1C1C1E` canvas, black 70%-opacity cards over regular Material, standard app system typography, and rounded geometry. Cards intentionally have no gold outline.
- The three steps omit separate content headers, subheaders, and gold eyebrow labels; the persistent progress indicator provides step context, followed by a consistent 20pt content gap. The 70pt logo/icon tile shares a row with the entity-name field and defaults to black. Both Personal and Business entities include a website field whose favicon automatically populates the logo preview.
- Personal / Business uses the shared gold active segment on a `#2C2C2E` track. Form fields and type controls also use `#2C2C2E`, matching the legacy sheet instead of the system blue segmented-control tint. The identity step does not expose an icon-color picker.
- Primary actions use a minimum 52pt height, visible disabled state, concise action-oriented labels, and native haptic feedback. Each step keeps its primary action directly below its card instead of pinning it to the screen edge. The identity step uses Zifr-green **Add Accounts →**. Accounts uses a Zifr-green **Connect via Plaid** action with the Plaid mark inside the black card. Its guidance recommends linking an active checking account or credit card, and the centered shield disclosure uses the technically explicit wording **Your data is encrypted in transit with TLS and protected at rest using AES-256 encryption.** A black **Set Up Later** button sits below the card; the prior bottom recommendation badge is removed. Both Review variants use Zifr-green completion actions.
- The Plaid review imports the connected bank's favicon-style logo into the institution header. Its account rows expose account name, type, masked identifier, balance, green selection state, Select all/Clear, and an accessible selected/not-selected label without a second decorative account icon.
- Edit mode adds a native red bordered **Delete Account** action at the bottom of Entity. It always requires a destructive confirmation; shared entities use the corresponding Leave Account action instead.

### Safety and recovery

- The primary identity action is unavailable until a trimmed entity name exists.
- Cancel on Entity and Close on Accounts immediately dismiss and discard the in-memory draft. No entity identity is persisted unless the user presses Save, chooses Set Up Later, or completes a Plaid connection. Set Up Later commits the entity before its alternate Review. Abandoning an already returned Plaid connection retains context-specific confirmation language because that connection has committed the entity.
- Plaid authentication stays in Plaid Link; Miloom does not request bank credentials. Account import occurs only after review and requires at least one selected account.
- A failed account save leaves the entity intact and keeps the review available for retry.

### Implementation anchors

- New flow, account review, and Plaid-to-domain mapping: `zifr-ios/Zifr/Views/Company/EditCompanySheet.swift` (`NewEntitySheet`)
- Dashboard presentation and completion routing: `zifr-ios/Zifr/Views/Dashboard/DashboardView.swift`
- Reusable Plaid launch control and Miloom color customization: `zifr-ios/Zifr/Views/Financial/PlaidLinkButton.swift`
