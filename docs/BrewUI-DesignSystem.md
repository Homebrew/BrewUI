# BrewUI Design System

> Derived from the [brew.sh](https://brew.sh) visual identity.  
> Adapted for a native macOS SwiftUI application — light and dark modes.

---

## 1. Design Principles

| Principle | Description |
|---|---|
| **Faithful to Homebrew** | Amber/golden brand colour, dark surfaces, monospaced code — carry the brew.sh identity into the app. |
| **macOS-native first** | Respect HIG conventions: vibrancy, semantic roles, system fonts as the base. |
| **Progressive disclosure** | Hierarchy through colour weight and surface depth, not decoration. |
| **Terminal roots** | Code blocks and command output retain a terminal-like aesthetic as a first-class element. |
| **System accent + brand layer** | Standard system controls (checkboxes, toggles, focus rings) use the user's chosen system accent colour via SwiftUI's `.tint()`. Homebrew amber is applied only to fully custom BrewUI components where `.tint()` would not apply. See Section 5 for the explicit boundary. |

---

## 2. Brand Palette (Source Colours)

These are the raw named colours extracted from the brew.sh visual identity. They are the foundation from which semantic tokens below are derived. Do not use these directly in components — use the semantic tokens in Section 4.

```
Amber 500    #FBB040   // Primary brand — beer amber, Homebrew logo
Amber 400    #FCC96B   // Lighter amber for highlights / hover
Amber 600    #E8971C   // Deeper amber for pressed states
Amber 100    #FEF3DC   // Very pale amber — light mode tinted surface

Hops Dark    #1A1A1A   // Near-black background (brew.sh page bg)
Hops 900     #222222   // Slightly lifted dark surface
Hops 800     #2D2D2D   // Card / sidebar dark surface
Hops 700     #3A3A3A   // Elevated surface / popover dark
Hops 600     #4A4A4A   // Border / divider dark
Hops 400     #6B6B6B   // Secondary text / placeholder dark
Hops 200     #B0B0B0   // Tertiary text dark
Hops 100     #D4D4D4   // Quaternary text dark

Cellar White  #F5F5F0  // Warm off-white (light mode base — avoids stark pure white)
Cellar 50     #FAFAF7  // Lightest surface (elevated card in light)
Cellar 100    #EFEFEA  // Standard surface light
Cellar 200    #E2E2DC  // Grouped / recessed surface light
Cellar 400    #9C9C96  // Secondary text light
Cellar 600    #5C5C58  // Tertiary text light
Cellar 900    #1A1A18  // Primary text light (warm near-black)

Green OK      #3CB371   // Success / installed
Red Error     #D9534F   // Error / destructive
Yellow Warn   #F0AD4E   // Warning / outdated
Blue Info     #5B9BD5   // Informational / link
```

---

## 3. Typography

### 3.1 Type Scale

The brew.sh site uses a clean sans-serif for prose and a monospaced font for all code/commands. The macOS app follows the same two-family split, but anchors to system fonts for native rendering quality.

| Role | Font | macOS Token | Fallback / Note |
|---|---|---|---|
| **Display** | SF Pro Display | `.title` / `.largeTitle` | Used for app name, empty states |
| **Heading** | SF Pro Display Semibold | `.title2`, `.title3` | Section headers, panel titles |
| **Body** | SF Pro Text Regular | `.body` | Standard readable text |
| **Label** | SF Pro Text Medium | `.callout`, `.subheadline` | List row labels, form labels |
| **Caption** | SF Pro Text Regular | `.caption`, `.caption2` | Metadata, timestamps, version strings |
| **Code / Command** | SF Mono Regular | `.body` with `.monospaced()` | Command output, brew commands |
| **Code Bold** | SF Mono Semibold | `.body` with `.monospaced()` | Command verb highlight (e.g. `brew install`) |

### 3.2 Size Ramp

| Token | Size (pt) | Line Height | Usage |
|---|---|---|---|
| `fontSize.largeTitle` | 28 | 34 | Empty state headings |
| `fontSize.title1` | 22 | 28 | Page/section title |
| `fontSize.title2` | 17 | 22 | Panel header |
| `fontSize.title3` | 15 | 20 | Sub-section header |
| `fontSize.body` | 13 | 18 | Standard body text (macOS default) |
| `fontSize.callout` | 12 | 16 | Secondary info rows |
| `fontSize.caption` | 11 | 14 | Metadata, badges |
| `fontSize.code` | 12 | 18 | Terminal / command output (SF Mono) |
| `fontSize.codeSmall` | 11 | 16 | Inline code references |

---

## 4. Semantic Colour Tokens

All component and layout work should reference these tokens only. Values are given for both **light** and **dark** modes.

### 4.1 Backgrounds

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.background.windowBase` | `Cellar White #F5F5F0` | `Hops Dark #1A1A1A` | Root window background |
| `color.background.surface` | `Cellar 50 #FAFAF7` | `Hops 900 #222222` | Cards, panels, list backgrounds |
| `color.background.surfaceElevated` | `#FFFFFF` | `Hops 800 #2D2D2D` | Popovers, sheets, floating panels |
| `color.background.surfaceRecessed` | `Cellar 200 #E2E2DC` | `Hops Dark #1A1A1A` | Grouped table background, sidebar |
| `color.background.terminal` | `#1E1E1E` | `#141414` | Command console / log output (always near-black) |

### 4.2 Text

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.text.primary` | `Cellar 900 #1A1A18` | `#F0F0ED` | Main content text |
| `color.text.secondary` | `Cellar 600 #5C5C58` | `Hops 200 #B0B0B0` | Supporting text, subtitles |
| `color.text.tertiary` | `Cellar 400 #9C9C96` | `Hops 400 #6B6B6B` | Placeholders, disabled labels |
| `color.text.link` | `Blue Info #5B9BD5` | `#7AB3E0` | Hyperlinks, tappable secondary actions |
| `color.text.onBrand` | `#1A1A1A` | `#1A1A1A` | Text placed on amber brand surfaces (always dark) |
| `color.text.codeDefault` | `#D4D4D4` | `#D4D4D4` | Default terminal/code text (always light on dark terminal bg) |
| `color.text.codeCommand` | `Amber 400 #FCC96B` | `Amber 400 #FCC96B` | brew command verbs in console |
| `color.text.codeArgument` | `#A8D8A8` | `#A8D8A8` | Formula/cask names in console |
| `color.text.codeOutput` | `#C8C8C8` | `#C8C8C8` | Standard stdout in console |
| `color.text.codeError` | `#FF7B72` | `#FF7B72` | stderr / error output in console |

### 4.3 Brand / Accent

> **Accent colour strategy:** macOS does not expose whether a user has customised their system accent colour, so it is not possible to fall back to amber only when the system default is active. Instead, BrewUI uses a deliberate split: **system accent for all standard SwiftUI controls** (applied via `.tint()` at the root), and **Homebrew amber for fully custom BrewUI-owned components** where `.tint()` has no effect. This respects user preference on system controls while applying clear brand identity where BrewUI has full ownership. See Section 5 for the per-component breakdown.

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.brand.primary` | `Amber 500 #FBB040` | `Amber 500 #FBB040` | Custom BrewUI components only — progress bars, console cursor, sidebar indicator, install action button |
| `color.brand.primaryHover` | `Amber 400 #FCC96B` | `Amber 400 #FCC96B` | Hover state on custom brand elements |
| `color.brand.primaryPressed` | `Amber 600 #E8971C` | `Amber 600 #E8971C` | Pressed/active state on custom brand elements |
| `color.brand.tint` | `Amber 100 #FEF3DC` | `rgba(251,176,64, 0.12)` | Sidebar selected item background, package row highlight |

### 4.4 Semantic Status

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.status.success` | `Green OK #3CB371` | `#52C98A` | Installed badge, success alert |
| `color.status.successSubtle` | `#EBF7F1` | `rgba(60,179,113,0.15)` | Success row tint |
| `color.status.warning` | `Yellow Warn #F0AD4E` | `#F5C26B` | Outdated package badge, warning alert |
| `color.status.warningSubtle` | `#FEF8EC` | `rgba(240,173,78,0.15)` | Warning row tint |
| `color.status.error` | `Red Error #D9534F` | `#E87370` | Failed install, error alert |
| `color.status.errorSubtle` | `#FDECEB` | `rgba(217,83,79,0.15)` | Error row tint |
| `color.status.info` | `Blue Info #5B9BD5` | `#7AB3E0` | Info alerts, update notifications |
| `color.status.infoSubtle` | `#EBF3FB` | `rgba(91,155,213,0.15)` | Info row tint |

### 4.5 Borders & Separators

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.border.default` | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.08)` | Standard card/panel border |
| `color.border.strong` | `rgba(0,0,0,0.16)` | `rgba(255,255,255,0.16)` | Focused input ring, prominent divider |
| `color.border.brand` | `Amber 500 #FBB040` | `Amber 500 #FBB040` | Focused field brand ring |
| `color.border.separator` | `rgba(0,0,0,0.06)` | `rgba(255,255,255,0.06)` | List row separator |

---

## 5. Component Tokens

> **System accent vs. Homebrew amber — the boundary:**
>
> | Uses system accent (`.tint()`) | Uses Homebrew amber (`color.brand.primary`) |
> |---|---|
> | `Toggle` on-state | Install/upgrade `ProgressView` fill |
> | `Checkbox` / `Toggle` in forms | Console cursor & progress indicator |
> | `Picker` selection | Sidebar selected item indicator |
> | Text selection highlight | Primary action `Button` (custom style) |
> | Default SwiftUI focus ring | Active tab / filter bar indicator |
> | `DatePicker`, `Slider` thumb | Package row selected background tint |
> | Any control using `.buttonStyle(.borderedProminent)` by default | SF Symbol tint on selected sidebar items |
>
> In SwiftUI, apply `.tint(Color.accentColor)` at the root `WindowGroup` level and do not override it on standard controls. Apply `color.brand.primary` explicitly only on the custom components listed above.

### 5.1 Buttons

BrewUI uses a fully custom primary button style — this is one of the components where amber applies. Secondary and destructive buttons use system-standard styling.

| Token | Light | Dark | Note |
|---|---|---|---|
| `button.primary.background` | `Amber 500 #FBB040` | `Amber 500 #FBB040` | **Custom amber** — not system accent |
| `button.primary.backgroundHover` | `Amber 400 #FCC96B` | `Amber 400 #FCC96B` | |
| `button.primary.backgroundPressed` | `Amber 600 #E8971C` | `Amber 600 #E8971C` | |
| `button.primary.foreground` | `#1A1A1A` | `#1A1A1A` | Always dark — amber fails contrast with white |
| `button.secondary.background` | `Cellar 100 #EFEFEA` | `Hops 700 #3A3A3A` | Standard bordered style |
| `button.secondary.backgroundHover` | `Cellar 200 #E2E2DC` | `Hops 600 #4A4A4A` | |
| `button.secondary.foreground` | `Cellar 900 #1A1A18` | `#F0F0ED` | |
| `button.destructive.background` | `Red Error #D9534F` | `#E87370` | Explicit red — never amber |
| `button.destructive.foreground` | `#FFFFFF` | `#FFFFFF` | |
| `button.cornerRadius` | `6pt` | `6pt` | |

### 5.2 Text Fields / Search

Text fields use the system focus ring (system accent) rather than an amber override. The border token is used for the unfocused state only.

| Token | Light | Dark | Note |
|---|---|---|---|
| `textField.background` | `#FFFFFF` | `Hops 800 #2D2D2D` | |
| `textField.backgroundFocused` | `#FFFFFF` | `Hops 700 #3A3A3A` | |
| `textField.border` | `rgba(0,0,0,0.12)` | `rgba(255,255,255,0.12)` | Unfocused border only |
| `textField.borderFocused` | **system accent** | **system accent** | Let macOS render the focus ring — do not override |
| `textField.placeholder` | `Cellar 400 #9C9C96` | `Hops 400 #6B6B6B` | |
| `textField.cornerRadius` | `6pt` | `6pt` | |

### 5.3 List Rows

Standard `List` selection uses the system accent. The amber tint is applied only to custom package rows with a distinct "selected for action" state (e.g. queued for batch install).

| Token | Light | Dark | Note |
|---|---|---|---|
| `listRow.background` | `#FFFFFF` | `Hops 900 #222222` | |
| `listRow.backgroundHover` | `Cellar 100 #EFEFEA` | `Hops 800 #2D2D2D` | |
| `listRow.backgroundSelected` | **system accent (auto)** | **system accent (auto)** | Standard `List` selection — respect system |
| `listRow.backgroundQueued` | `Amber 100 #FEF3DC` | `rgba(251,176,64,0.15)` | **Custom amber** — "queued for action" state, distinct from selection |
| `listRow.separatorColor` | `rgba(0,0,0,0.06)` | `rgba(255,255,255,0.06)` | |

### 5.4 Sidebar

The sidebar active item indicator is a custom drawn element — amber applies here.

| Token | Light | Dark | Note |
|---|---|---|---|
| `sidebar.background` | `Cellar 200 #E2E2DC` | `Hops Dark #1A1A1A` | |
| `sidebar.itemDefault` | `Cellar 900 #1A1A18` | `#D4D4D4` | |
| `sidebar.itemSelected.background` | `Amber 100 #FEF3DC` | `rgba(251,176,64,0.18)` | **Custom amber** — fully custom component |
| `sidebar.itemSelected.foreground` | `Amber 600 #E8971C` | `Amber 400 #FCC96B` | **Custom amber** |
| `sidebar.itemSelected.indicator` | `Amber 500 #FBB040` | `Amber 500 #FBB040` | Leading edge pill/bar indicator |

### 5.5 Progress & Install State

Progress indicators during install/upgrade operations are a core BrewUI-branded moment — amber applies.

| Token | Value | Note |
|---|---|---|
| `progress.trackColor` | `rgba(0,0,0,0.08)` light / `rgba(255,255,255,0.08)` dark | Background track |
| `progress.fillColor` | `Amber 500 #FBB040` | **Custom amber** — `.tint(color.brand.primary)` on `ProgressView` |
| `progress.indeterminate` | `Amber 500 #FBB040` | Spinner during brew command execution |

### 5.6 Badges

| Token | Light | Dark |
|---|---|---|
| `badge.installed.background` | `color.status.successSubtle` | `color.status.successSubtle` |
| `badge.installed.foreground` | `Green OK #3CB371` | `#52C98A` |
| `badge.outdated.background` | `color.status.warningSubtle` | `color.status.warningSubtle` |
| `badge.outdated.foreground` | `#B07D2A` | `Yellow Warn #F0AD4E` |
| `badge.cornerRadius` | `4pt` | `4pt` |
| `badge.fontSize` | `fontSize.caption (11pt)` | `fontSize.caption (11pt)` |

### 5.7 Command Console

The console is intentionally always dark — this is the "terminal roots" principle in action. It does not invert to a light surface in light mode. It uses a fixed palette.

| Token | Value | Usage |
|---|---|---|
| `console.background` | `#1E1E1E` | Console pane background |
| `console.backgroundInset` | `#141414` | Inner scroll area |
| `console.border` | `rgba(255,255,255,0.08)` | Console panel border |
| `console.textDefault` | `#C8C8C8` | General output text |
| `console.textCommand` | `Amber 400 #FCC96B` | brew command and verb |
| `console.textArgument` | `#A8D8A8` | Formula / cask name argument |
| `console.textSuccess` | `#52C98A` | Success confirmation lines |
| `console.textWarning` | `Yellow Warn #F0AD4E` | Warning lines |
| `console.textError` | `#FF7B72` | Error / stderr lines |
| `console.textDimmed` | `#6B6B6B` | Verbose / debug lines |
| `console.cursorColor` | `Amber 500 #FBB040` | **Custom amber** — animated cursor / progress indicator |
| `console.fontFamily` | `SF Mono` | — |
| `console.fontSize` | `12pt` | — |
| `console.lineHeight` | `18pt` | — |

---

## 6. Spacing & Layout

Follows an 8pt base grid, with a 4pt half-step for tight internal spacing.

| Token | Value | Usage |
|---|---|---|
| `spacing.xxs` | `2pt` | Icon-to-label gap, badge padding |
| `spacing.xs` | `4pt` | Tight internal padding |
| `spacing.sm` | `8pt` | Standard internal padding, row insets |
| `spacing.md` | `12pt` | Section internal padding |
| `spacing.lg` | `16pt` | Panel padding, card insets |
| `spacing.xl` | `24pt` | Between sections |
| `spacing.xxl` | `32pt` | Empty state vertical margins |
| `layout.sidebarWidth` | `220pt` | Default sidebar width |
| `layout.inspectorWidth` | `280pt` | Detail inspector panel width |
| `layout.minWindowWidth` | `800pt` | Minimum supported window width |
| `layout.minWindowHeight` | `520pt` | Minimum supported window height |

---

## 7. Corner Radii

| Token | Value | Usage |
|---|---|---|
| `radius.sm` | `4pt` | Badges, tags, small chips |
| `radius.md` | `6pt` | Buttons, text fields, cards |
| `radius.lg` | `10pt` | Panels, sheets, popovers |
| `radius.xl` | `14pt` | Modal windows, onboarding cards |

---

## 8. Elevation & Shadow

macOS uses vibrancy and material layers rather than heavy shadows. Use `.ultraThinMaterial` / `.regularMaterial` SwiftUI modifiers where possible. The tokens below are for contexts where explicit shadows are required (e.g. floating panels in non-vibrancy contexts).

| Token | Light Value | Dark Value | Usage |
|---|---|---|---|
| `shadow.sm` | `0 1pt 3pt rgba(0,0,0,0.10)` | `0 1pt 4pt rgba(0,0,0,0.40)` | Cards resting on surface |
| `shadow.md` | `0 4pt 12pt rgba(0,0,0,0.12)` | `0 4pt 16pt rgba(0,0,0,0.50)` | Popovers, dropdown menus |
| `shadow.lg` | `0 8pt 24pt rgba(0,0,0,0.14)` | `0 8pt 32pt rgba(0,0,0,0.60)` | Sheets, modal windows |

---

## 9. Iconography

- Use **SF Symbols** throughout. Minimum symbol weight: **Regular**; use **Medium** for toolbar icons.
- Primary icon tint: `color.brand.primary` (amber) for selected/active states; `color.text.secondary` for default.
- Do not use multicolour symbols except for the app icon itself.
- Recommended symbols per context:

| Context | SF Symbol |
|---|---|
| Package / Formula | `shippingbox` |
| Cask / App | `app.badge` |
| Install | `arrow.down.circle` |
| Uninstall | `trash` |
| Update | `arrow.triangle.2.circlepath` |
| Upgrade All | `arrow.up.circle.fill` |
| Search | `magnifyingglass` |
| Console / Log | `terminal` |
| Settings | `gearshape` |
| Outdated | `exclamationmark.triangle` |
| Tap | `externaldrive.connected.to.line.below` |
| Info | `info.circle` |

---

## 10. Motion & Animation

Follow macOS standard animation curves. Avoid custom spring configs unless matching system defaults.

| Token | Value | Usage |
|---|---|---|
| `animation.fast` | `0.15s easeOut` | Button state changes, badge updates |
| `animation.standard` | `0.25s easeInOut` | Panel transitions, list insertions |
| `animation.slow` | `0.35s easeInOut` | Sheet presentation, modal entrance |
| `animation.spring` | `spring(response: 0.35, dampingFraction: 0.75)` | Sidebar expand/collapse |

---

## 11. Accessibility Targets

| Requirement | Value |
|---|---|
| Minimum text contrast (WCAG AA) | 4.5:1 for body text |
| Brand amber on dark bg contrast | `#FBB040` on `#1A1A1A` → **8.1:1** ✓ |
| Brand amber on white contrast | `#FBB040` on `#FFFFFF` → **2.7:1** — use dark text on amber surfaces, never amber text on white |
| Minimum tap / click target | `44 × 44pt` |
| Focus ring colour | **System accent** (do not override — macOS renders this automatically) |
| Support Dynamic Type | Yes — use relative SwiftUI font styles, not fixed sizes |
| Reduce Motion support | Yes — check `accessibilityReduceMotion` |

---

## 12. Figma Variable Naming Convention

When implementing these tokens in Figma Variables, use the following slash-delimited naming:

```
Color/Background/Window Base
Color/Background/Surface
Color/Background/Surface Elevated
Color/Background/Surface Recessed
Color/Background/Terminal

Color/Text/Primary
Color/Text/Secondary
Color/Text/Tertiary
Color/Text/Link
Color/Text/On Brand
Color/Text/Code Default
Color/Text/Code Command
Color/Text/Code Argument
Color/Text/Code Output
Color/Text/Code Error

Color/Brand/Primary
Color/Brand/Primary Hover
Color/Brand/Primary Pressed
Color/Brand/Tint

Color/Status/Success
Color/Status/Success Subtle
Color/Status/Warning
Color/Status/Warning Subtle
Color/Status/Error
Color/Status/Error Subtle
Color/Status/Info
Color/Status/Info Subtle

Color/Border/Default
Color/Border/Strong
Color/Border/Brand
Color/Border/Separator

Number/Spacing/XXS  → 2
Number/Spacing/XS   → 4
Number/Spacing/SM   → 8
Number/Spacing/MD   → 12
Number/Spacing/LG   → 16
Number/Spacing/XL   → 24
Number/Spacing/XXL  → 32

Number/Radius/SM    → 4
Number/Radius/MD    → 6
Number/Radius/LG    → 10
Number/Radius/XL    → 14
```

Each colour variable should have two modes: **Light** and **Dark**.

---

*BrewUI Design System v1.1 — generated for Figma prototype integration*
