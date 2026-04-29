---
name: Cifr Entrepreneur Manager
colors:
  primary: "#223e5a"
  secondary: "#2B3A3B"
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
