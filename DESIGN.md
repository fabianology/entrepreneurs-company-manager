---
name: Cifr Entrepreneur Manager
colors:
  primary: "#1FE400"
  secondary: "#0091FF"
  tertiary: "#EBC351"
  background: "#000000"
  surface: "#171717"
  surface-dim: "#111111"
  surface-glass: "#1c1c1e"
  on-surface: "#ffffff"
  on-surface-variant: "rgba(255, 255, 255, 0.35)"
  outline: "rgba(255, 255, 255, 0.08)"
  outline-variant: "rgba(255, 255, 255, 0.05)"
  error: "#ff0000"
  warning: "#ffa500"
typography:
  label-sm:
    fontFamily: System
    fontSize: 9px
    fontWeight: "900"
    letterSpacing: 1.5px
    textTransform: uppercase
  label-md:
    fontFamily: System
    fontSize: 11px
    fontWeight: "900"
    letterSpacing: 2px
    textTransform: uppercase
  body-md:
    fontFamily: System
    fontSize: 13px
    fontWeight: "500"
  body-lg:
    fontFamily: System
    fontSize: 14px
    fontWeight: "600"
rounded:
  sm: 8px
  md: 10px
  lg: 14px
  xl: 24px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  card-padding: 16px
components:
  glass-card:
    backgroundColor: "{colors.surface-glass}"
    rounded: "{rounded.xl}"
    outline: "1px solid {colors.outline-variant}"
  liquid-glass:
    backgroundColor: "rgba(255, 255, 255, 0.2)"
    rounded: "{rounded.xl}"
    outline: "0.5px solid rgba(255, 255, 255, 0.2)"
    boxShadow: "0px 4px 12px rgba(0, 0, 0, 0.15)"
  input-field:
    backgroundColor: "{colors.surface-dim}"
    rounded: "{rounded.lg}"
    outline: "1px solid rgba(255, 255, 255, 0.1)"
    padding: "12px 16px"
  cifr-field:
    backgroundColor: "rgba(0, 0, 0, 0.4)"
    rounded: "{rounded.sm}"
    outline: "1px solid {colors.outline-variant}"
    padding: "10px 12px"
---

## Brand & Style
Cifr is a dark-mode native, high-density entrepreneur's company manager designed with a strict adherence to modern iOS (HIG) paradigms. The aesthetic is "Pro" and unapologetically data-centric, utilizing deep blacks, subtle greys, and striking neon accents to create a hierarchy that feels instantly responsive and professional. It embraces a "glass-over-darkness" philosophy, contrasting stark black backgrounds with elevated glass cards to define spatial relationships without visual clutter.

## Colors
The color strategy relies on maximum contrast on a pure black canvas to minimize eye strain while ensuring absolute clarity of financial and operational data.

- **Primary Canvas:** Pure Black (`#000000`) serves as the infinite void, allowing data to be the primary focus.
- **Surfaces:** Dark greys (`#171717` to `#1C1C1E`) are used to elevate cards and group information.
- **Accents:** High-vibrancy neon colors like Zifr Green (`#1FE400`), Blue (`#0091FF`), and Gold (`#EBC351`) are used sparingly for status indicators, active states, and critical semantic meaning.
- **Borders & Separators:** Almost invisible white opacities (5% to 10%) are used to draw hard edges without introducing solid, distracting lines.

## Typography
Typography is system-native (San Francisco/System), prioritized for extreme legibility in compact, high-density layouts.

- **Micro-Labels:** Heavy, wide-tracking uppercase labels (9pt-11pt Black weight) are used as section headers and field descriptors. They sit quietly in the background using `white/35` opacity but are instantly readable due to their extreme weight.
- **Data Values:** Inputs and copyable values use Semibold to Bold weights at 13pt-14pt, appearing in solid white to punch out from the dark background.
- **Hierarchy:** Font weight is used far more aggressively than size to establish hierarchy in tight spaces.

## Elevation & Depth
Depth is created through subtle layering of dark materials and native blurs, rather than traditional drop shadows which get lost on black backgrounds.

- **Level 0 (Background):** Pure black (`#000000`).
- **Level 1 (Cards & Modals):** `GlassCardModifier` using `#1C1C1E` with a 5% white border to catch the "light".
- **Level 2 (Floating/Overlays):** `LiquidGlassModifier` using native iOS regular materials, adding a delicate 15% opacity drop shadow and 20% white border to physically separate it from the base UI.

## Layout & Spacing
The layout champions extreme information density ("iOS 26-compliant" compact design language).

- **Radii:** A distinct corner radius hierarchy. Small internal elements (fields, buttons) use 8px (`rounded-sm`) to 14px (`rounded-lg`), while main architectural cards use a generous 24px (`rounded-xl`).
- **Inputs:** The bespoke `ZifrField` is designed for dense data entry, stacking tiny, bold labels directly above inputs within a single, unified `#111111` container.
- **Interactive Feedback:** Haptic feedback (`UIImpactFeedbackGenerator`) is a first-class citizen, paired with micro-animations on actions like copying values or revealing secure fields.
