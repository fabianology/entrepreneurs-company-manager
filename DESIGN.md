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

> Current entity-creation direction, implemented 2026-09-20. The old create-mode treatment above remains the named legacy reference; editing an existing entity continues to use `EditCompanySheet`.

### Product flow

1. **Entity:** capture the required name plus optional logo/icon, Personal or Business category, and the corresponding profile/business type.
2. **Connect:** persist the entity, then strongly recommend connecting at least one account with Plaid. The user may finish without accounts only through an explicit confirmation.
3. **Review:** show every returned Plaid account, preselect all of them, and let the user remove accounts before saving the institution, depository/investment accounts, cards, and loans.

The entity is saved before Plaid opens because the connection requires a stable entity ID. Canceling or failing Plaid never removes the entity. Successful completion opens the entity on its Financial tab.

### Visual system

- Full-height native sheet with a grabber, compact inline title, leading Cancel/Close control, and a three-stage progress indicator.
- Retains Miloom’s dark canvas, green depth glow, gold emphasis, system typography, brand-color palette, and rounded geometry.
- Content cards use native regular Material with a restrained dark tint and semantic separators. Liquid Glass is reserved for the bottom action/navigation layer on iOS 26 and later; iOS 17–18 use an `ultraThinMaterial` fallback.
- Primary actions use a minimum 52pt height, visible disabled state, concise action-oriented labels, and native haptic feedback. The persistent action shelf keeps the next action reachable without turning every content surface into glass.
- The review list exposes account name, type, masked identifier, balance, selection state, Select all/Clear, and an accessible selected/not-selected label.

### Safety and recovery

- The primary identity action is unavailable until a trimmed entity name exists.
- Unsaved identity dismissal, skipping Plaid, and abandoning a returned connection each use context-specific confirmation language.
- Plaid authentication stays in Plaid Link; Miloom does not request bank credentials. Account import occurs only after review and requires at least one selected account.
- A failed account save leaves the entity intact and keeps the review available for retry.

### Implementation anchors

- New flow, account review, and Plaid-to-domain mapping: `zifr-ios/Zifr/Views/Company/EditCompanySheet.swift` (`NewEntitySheet`)
- Dashboard presentation and completion routing: `zifr-ios/Zifr/Views/Dashboard/DashboardView.swift`
- Reusable Plaid launch control and Miloom color customization: `zifr-ios/Zifr/Views/Financial/PlaidLinkButton.swift`
