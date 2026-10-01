---
name: Executive Slate
colors:
  surface: '#001135'
  surface-dim: '#001135'
  surface-bright: '#003580'
  surface-container-lowest: '#000c2a'
  surface-container-low: '#001945'
  surface-container: '#001d4d'
  surface-container-high: '#002762'
  surface-container-highest: '#003177'
  on-surface: '#d9e2ff'
  on-surface-variant: '#c3c7cb'
  inverse-surface: '#d9e2ff'
  inverse-on-surface: '#002d6f'
  outline: '#8d9195'
  outline-variant: '#43474a'
  surface-tint: '#bac9d3'
  primary: '#ffffff'
  on-primary: '#24323a'
  primary-container: '#d6e5ef'
  on-primary-container: '#586670'
  inverse-primary: '#526069'
  secondary: '#93cdfc'
  on-secondary: '#00344f'
  secondary-container: '#00527b'
  on-secondary-container: '#8bc5f4'
  tertiary: '#ffffff'
  on-tertiary: '#003258'
  tertiary-container: '#d1e4ff'
  on-tertiary-container: '#0067ad'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#d6e5ef'
  primary-fixed-dim: '#bac9d3'
  on-primary-fixed: '#0f1d25'
  on-primary-fixed-variant: '#3b4951'
  secondary-fixed: '#cbe6ff'
  secondary-fixed-dim: '#93cdfc'
  on-secondary-fixed: '#001e30'
  on-secondary-fixed-variant: '#004b71'
  tertiary-fixed: '#d1e4ff'
  tertiary-fixed-dim: '#9ecaff'
  on-tertiary-fixed: '#001d36'
  on-tertiary-fixed-variant: '#00497d'
  background: '#001135'
  on-background: '#d9e2ff'
  surface-variant: '#003177'
typography:
  headline-lg:
    fontFamily: Poppins
    fontSize: 30px
    fontWeight: '600'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Poppins
    fontSize: 22px
    fontWeight: '600'
    lineHeight: 28px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Poppins
    fontSize: 17px
    fontWeight: '600'
    lineHeight: 22px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Geist
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.005em
  body-md:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 18px
    letterSpacing: 0.01em
  label-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.02em
  label-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.03em
  data-mono-lg:
    fontFamily: Plus Jakarta Sans
    fontSize: 20px
    fontWeight: '500'
    lineHeight: 24px
    letterSpacing: -0.02em
  data-mono-md:
    fontFamily: Plus Jakarta Sans
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 18px
    letterSpacing: -0.01em
  data-mono-sm:
    fontFamily: Plus Jakarta Sans
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 14px
    letterSpacing: 0em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 0.75rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 0.75rem
  space-lg: 1rem
  space-xl: 1.5rem
---

## Brand & Style

This design system establishes an executive-grade, hyper-disciplined personal computing environment engineered specifically for operators, developers, and investors. The product rejects ephemeral mobile consumer design trends—specifically generative AI aesthetics, decorative gradients, skeuomorphic orbs, and glassmorphic blurs—in favor of structural authority, architectural rhythm, and absolute information density.

The aesthetic draws primarily from Dieter Rams' functionalism merged with modern terminal ergonomics and Swiss typography. The design treats screen real estate as finite cognitive bandwidth:
- High data density balanced by disciplined internal whitespace rather than expansive void.
- Subdued monochromatic foundations where color operates exclusively as semantic telemetry (state changes, delta indicators, risk alerts).
- Absolute elimination of decorative ornamentation, ambient glow, non-system emoji glyphs, and non-functional animation.
- A physical, low-contrast precision layer that feels like machined obsidian or anodized matte metal.

## Colors

The color palette is strictly dark-first and operational. Chromatic light is reserved solely for actionable items, system status, and financial delta verification.

### Foundations & Surfaces
- **Canvas Base (`#0D47A1`):** The viewport root, persistent system bar background, and outer void.
- **Surface Primary (`#101418`):** Default card background, list container surface, and active execution context.
- **Surface Secondary (`#191C21`):** Nested component wells, selected segment fills, toolbars, and inactive inputs.
- **Surface Tertiary / Pressed (`#20242B`):** Active tap/touch feedback state.
- **Border / Structural (`#23272F`):** Standard 1px mechanical perimeter. A low-contrast alternate (`rgba(255, 255, 255, 0.06)`) is used for nested inner dividers.

### Typography & Content
- **Text Primary (`#F2F3F5`):** High-legibility off-white for metrics, titles, and imperative labels.
- **Text Secondary (`#8B919B`):** Descriptive metadata, subtitles, table column headers, and inactive navigational states.
- **Text Muted / Disabled (`#5F6670`):** Micro-labels, non-editable prefixes, timestamp indicators, and disabled actions.

### Accents & Telemetry
- **Primary Accent (`#E3F2FD`):** Focused inputs, active navigation indicators, key metrics, and primary confirmation triggers. Never used as a multi-stop gradient.
- **Success / Positive (`#90CAF9`):** Positive portfolio yield, completed deployment pipelines, validated health goals.
- **Critical / Negative (`#2196F3`):** Drawdowns, failing build states, high-priority system alerts.
- **Warning (`#E5A93C`):** Pending approvals, non-fatal anomalies.

## Typography

The typography couples the modern geometric sans-serif **Poppins** for headings, **Geist** for structural interaction and narrative content, with **Plus Jakarta Sans** for all numerical calculations, financial balances, code references, and machine states.

### Execution Rules
- **Tabular Figures:** Always apply `font-variant-numeric: tabular-nums` to financial data, percentages, timers, and timestamps. Numbers must align vertically across dense multi-row ledgers.
- **Section Headers:** Section titles must remain restrained. Avoid oversized headers. Standard section headers leverage `headline-sm` with `text-secondary`, rendered in sentence case rather than uppercase tracking.
- **Micro-Labels:** Use `label-sm` with slight positive tracking (`+0.03em`) for uppercase system status indicators (e.g., `RUNNING`, `LOCKED`, `SYNCED`).

## Layout & Spacing

The system enforces an explicit 4px baseline rhythm optimized for one-handed mobile Android interaction and compact information architecture.

### Grid & Form Factor Architecture
- **Mobile Handheld (360px – 430px):** Single-column stack conforming to a 4-column sub-grid with `12px` (`0.75rem`) gutters and `16px` (`1rem`) outer margins.
- **Tablet / Foldable Expanded (600px+):** Dual-pane split hierarchy (Navigation/List Master on left, Detail Workspace on right) utilizing an 8-column layout with `16px` gutters.

### Android Ergonomics & Safe Areas
- **Top Inset:** Hard-coded system status bar clearance (minimum `44px` or dynamic `env(safe-area-inset-top)`). The executive header sits directly below: fixed height of `48px`, featuring a non-scrollable workspace title and contextual state counter.
- **Bottom Navigation Surface:** Height fixed at `56px` excluding `env(safe-area-inset-bottom)`. The 4-tab anchor (Home, Finance, Goals, Projects) maintains strict symmetric division across the viewport width. Tap targets measure at minimum `48x48px` centered on stroke icons.
- **Vertical Rhythm:** Grouped lists and data modules maintain `space-sm` (`8px`) separation. High-level dashboard segments separate at `space-lg` (`16px`). Empty space must never exceed `space-xl` (`24px`).

## Elevation & Depth

This design system rejects ambient blur, multi-layered diffuse dropshadows, and 3D skeuomorphism. Depth is strictly expressed through **tonal stacking** and **1px structural borders**.

### Structural Tiers
1. **Level 0 (Canvas Base):** `#0D47A1`. The structural background. Does not elevate.
2. **Level 1 (Default Containers & Cells):** Surface Primary `#101418` with a continuous `1px solid #23272F` border. No shadow.
3. **Level 2 (In-Card Blocks & Inset Inputs):** Surface Secondary `#191C21`. Used to create inset wells or distinguish child blocks inside a Level 1 container.
4. **Level 3 (Overlays, Modals, & Bottom Sheets):** Surface Secondary `#191C21` bordered by `1px solid rgba(255, 255, 255, 0.1)`. A hard, sharp, non-tinted directional shadow is applied: `0 8px 24px rgba(0, 0, 0, 0.65)`. No backdrop blur is applied to behind layers; instead, the background dim uses an opaque solid scrim: `rgba(13, 71, 161, 0.8)`.

### Border Discipline
Dividers between continuous list items use hairline rules: `1px solid rgba(255, 255, 255, 0.04)` to prevent visual clutter. Exterior module walls always use `1px solid #23272F`.

## Shapes

The interface embraces a balanced, slightly rounded architectural geometry. Corner radii are moderately elevated to create a modern, approachable instrument-like quality. 

- **Level 1 Roundedness (`rounded-sm` / `0.375rem`):** Used for micro-badges, mono tags, inputs, and checkboxes.
- **Standard (`rounded-md` / `0.5rem`):** Used for standard buttons, segmented controls, and nested list items.
- **Container (`rounded-lg` / `1rem`):** Used for root data cards, dialog surfaces, and bottom sheets.
- **Pill shapes (`rounded-full`) are prohibited** except for circular avatar masks, active pulse indicators, and dedicated icon-only action triggers. Cards and standard chips must never feature capsule rounding.

## Components

### Buttons
- **Primary:** Background `#E3F2FD`, text `#0D47A1` (weight 600), border `none`, corner radius `8px`. Height `40px` (standard) or `32px` (dense). Active state transitions to `#90CAF9`.
- **Secondary / Ghost:** Background `#191C21`, text `#F2F3F5`, border `1px solid #23272F`. Active state shifts background to `#20242B`.
- **Destructive:** Background `transparent`, text `#2196F3`, border `1px solid rgba(33, 150, 243, 0.2)`. Active state shifts border to `#2196F3`.

### Navigation Bar (Mobile Android)
- **Container:** Background `#0D47A1`, top border `1px solid #23272F`, safe-area bottom padded. Height `56px`.
- **Tabs (Home, Finance, Goals, Projects):** Uniform 4-column distribution. SVG stroke width `1.75px`. Active tab icon and micro-label render in `#E3F2FD`. Inactive tabs render in `#5F6670`. No active pill indicator backgrounds.

### Cards & Data Containers
- Solid `#101418` fill, `1px solid #23272F`, corner radius `12px`, inner padding `12px` to `16px`.
- **Card Header:** Single horizontal line containing title (`label-md`, `#8B919B`) and an optional numeric badge (`data-mono-sm`).
- **Card Body:** No extra visual nesting unless placed inside a `#191C21` well.

### Data Metric Displays (Finance & Execution)
- Visual stack containing label (`label-sm`, `#5F6670`), metric value (`data-mono-lg`, `#F2F3F5`), and delta pill (`data-mono-sm`).
- Delta pill background: `rgba(144, 202, 249, 0.1)` with `#90CAF9` text for gains; `rgba(33, 150, 243, 0.1)` with `#2196F3` text for losses. Border is `1px solid currentColor` at 20% opacity.

### List Items & Tables
- Dense vertical rows, fixed height `44px` or `52px`.
- Left-aligned primary label with secondary metadata placed below in `body-sm` (`#8B919B`).
- Right-aligned tabular value in `data-mono-md`.
- Hairline divider (`1px solid rgba(255, 255, 255, 0.04)`) spanning edge-to-edge inside the container.

### Inputs & Search Bars
- Background `#191C21`, border `1px solid #23272F`, text `#F2F3F5`, placeholder `#5F6670`. Corner radius `8px`.
- Height `36px` for dense search; `44px` for direct data entry.
- Focus state: `1px solid #E3F2FD` without outer glow rings. Monospace type is used whenever numbers, commands, or keys are being inserted.

### Chips & Filters
- Background `#101418`, border `1px solid #23272F`, text `#8B919B`, radius `6px`, padding `4px 8px`.
- Selected state: Background `#191C21`, border `1px solid #E3F2FD`, text `#F2F3F5`.

### Checkboxes & Binary Selectors
- Dimensions `16x16px`, corner radius `4px`, border `1.5px solid #5F6670`, background `transparent`.
- Checked state: Border `#E3F2FD`, background `#E3F2FD`, tick glyph `#0D47A1`.