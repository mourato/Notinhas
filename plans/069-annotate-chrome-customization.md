# Plan 069: Customize Annotate editor chrome order and visibility

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 92ac11a9..HEAD -- \
>   Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift \
>   Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift \
>   Notinhas/Features/Annotate/Models/AnnotateAnnotationToolType.swift \
>   Notinhas/Features/QuickAccess/Models/QuickAccessActionConfigurationStore.swift \
>   Notinhas/Features/Preferences/Components/PreferencesQuickAccessActionCustomizationView.swift \
>   Notinhas/Features/Preferences/Components/PreferencesAnnotateSettingsView.swift \
>   Notinhas/Features/Preferences/Models/PreferencesKeys.swift`
> On blocking mismatch vs "Current state", STOP.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: MED
- **Depends on**: none (builds on Quick Access customization pattern; after 068 dock rename preferred)
- **Category**: direction / usability
- **Planned at**: commit `92ac11a9`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` with concurrent Annotate toolbar or Quick Access prefs refactors
- **Reviewer required**: `yes` — shared prefs list extract + Annotate chrome + QA regression
- **Rationale**: Shared Preferences list component, new Annotate store, toolbar/bottom-bar consumers, QA adopt.
- **Escalate when**: Product asks for card-slot positioning on Annotate (rejected) or customizing zoom/mode tabs.

## Why this matters

Quick Access already lets users reorder and enable/disable actions
([`QuickAccessActionConfigurationStore`](Notinhas/Features/QuickAccess/Models/QuickAccessActionConfigurationStore.swift) +
[`QuickAccessActionCustomizationView`](Notinhas/Features/Preferences/Components/PreferencesQuickAccessActionCustomizationView.swift)).
The Annotate editor toolbar and bottom bar are still hardcoded. Users who never
use Watermark, Rotate, or Cloud want them gone and their remaining tools ordered
for speed.

This plan **reuses the design/engineering pattern** and **extracts a shared Preferences list component** so Annotate does not fork a second drag/toggle implementation.

## Confirmed product decisions

1. **Surfaces:** Drawing tools **and** top chrome (Crop, Add background, Rotate, Cutout, Save as) **and** bottom-bar actions (New window, Share, ImgBB, Cloud, Pin, Copy, Delete).
2. **Model:** Order + enable/disable **only** — no card slot badges on Annotate (“Center top”, etc.).
3. **Always visible (not disableable):** Selection, Undo, Redo, Done.
4. **Not in this plan:** Zoom menu, pan, Annotate/Preview/Mockup mode tabs, Drag to app (fixed chrome).
5. **Prefs UI:** Annotate Preferences sections using the **same shared list component** as Quick Actions (drag reorder, toggle, Reset) — **no** card preview for Annotate.
6. **Inline annotate:** Use the same **drawing-tool** order/enable subset so Capture Markup stays consistent; leave non-drawable chrome alone in inline.
7. **Shared component (required):** Extract Preferences reorder+toggle list chrome; **adopt it in Quick Access** (keep slot badge as an optional accessory) **and** Annotate. Do not copy-paste a second row implementation.

## Current state

- Toolbar: [`AnnotateToolbarView`](Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift) — fixed L→R undo/redo ‖ crop/background/rotate ‖ selection+`drawableTools`+cutout ‖ Save as/Done.
- Bottom: [`AnnotateBottomBarView`](Notinhas/Features/Annotate/Components/AnnotateBottomBarView.swift) — fixed right actions.
- Tools list: `AnnotationToolType.drawableTools` in [`AnnotateAnnotationToolType.swift`](Notinhas/Features/Annotate/Models/AnnotateAnnotationToolType.swift).
- Closest prefs: shortcut disable only (`AnnotateShortcutManager`) — does **not** hide toolbar buttons.
- Quick Access list UI is private in `PreferencesQuickAccessActionCustomizationView.swift` (`QuickAccessActionConfigurationRow`) with drag-handle reorder + optional slot-assignment drag + placement badge + Toggle.

## Shared Preferences component (required extract)

Create under Preferences/Components, e.g.:

- `PreferencesReorderToggleList.swift` — section body: caption, `ForEach` rows, dividers, optional footer (`Reset`), mouse-up drag cleanup monitor pattern from QA
- `PreferencesReorderToggleRow.swift` — row: drag handle, leading icon+title, optional **trailing accessory** (`ViewBuilder`), Toggle

API shape (adjust names to fit SwiftUI style; keep generic over `Identifiable`):

```swift
struct PreferencesReorderToggleList<Item: Identifiable, Accessory: View>: View {
  let items: [Item]
  let title: (Item) -> String
  let systemImage: (Item) -> String
  let isEnabled: (Item) -> Binding<Bool>
  let canReorder: (Item) -> Bool      // false → no handle / not draggable
  let canToggle: (Item) -> Bool       // false → toggle on + disabled
  let onMove: (IndexSet, Int) -> Void
  @ViewBuilder var accessory: (Item) -> Accessory
  // optional reset button label + action
}
```

**Quick Access adopt:**

- Refactor the **Quick Actions list section** (not the card preview) to use `PreferencesReorderToggleList`.
- Slot placement badge stays via `accessory`.
- Keep existing QA behaviors: handle-only reorder drag, separate row-body drag for slot assignment, `UTType.quickAccessReorder`, `DragTrackingItemProvider`, Reset Actions (+ swipe reset) unchanged in meaning.
- Do **not** move card preview / slot drop targets into the shared list.

**Annotate adopt:**

- Toolbar and bottom sections use the same list with `accessory: { EmptyView() }` (or omit accessory).
- Customizable-only rows in the lists; footnote naming always-on anchors (Selection, Undo, Redo, Done). Prefer not showing locked always-on rows unless needed for clarity — footnote is enough.

**Regression bar:** After extract, Quick Access Preferences list still reorders, toggles, shows badges, resets; card slot drag still works.

## Data model (Annotate-specific — do not overload QuickAccessActionKind)

```swift
enum AnnotateChromeItem: String, CaseIterable, Identifiable, Codable {
  // Always-on (runtime anchors; not stored as disableable)
  case undo, redo, selection, done

  // Top chrome (customizable)
  case crop, addBackground, rotateLeft, rotateRight, backgroundCutout, saveAs

  // Drawing tools (customizable)
  case rectangle, filledRectangle, oval, arrow, line, text, highlighter,
       blur, spotlight, notinhasNote, watermark, pencil

  // Bottom actions (customizable)
  case newWindow, share, uploadToImgBB, uploadToCloud, pin, copy, delete
}
```

Store only customizable orders:

1. `toolbarItemOrder` — customizable toolbar items
2. `bottomActionOrder` — bottom customizable actions
3. `enabledItems: Set<AnnotateChromeItem>` — always-on always forced enabled in normalization

Persistence (`PreferencesKeys`):

| Key | Type |
|-----|------|
| `annotate.chrome.toolbarOrder.v1` | `[String]` |
| `annotate.chrome.bottomOrder.v1` | `[String]` |
| `annotate.chrome.enabled.v1` | `[String]` |

Store: `AnnotateChromeConfigurationStore` (`@MainActor`, `ObservableObject`, testable `UserDefaults` init) with `move`, `setEnabled`, ordered getters, `resetToDefaults()`, normalization.

## Always-on layout anchors (runtime)

| Anchor | Position |
|--------|----------|
| Undo, Redo | Leading pair + divider (as today after 064) |
| Selection | First tool after capture chrome group |
| Done | Trailing primary (crop Apply/Cancel/Restore unchanged when cropping) |

Customizable toolbar items in user order within natural groups:

1. After Undo/Redo divider: capture chrome among `{crop, addBackground, rotateLeft, rotateRight}` (preserve sensible dividers).
2. After next divider: Selection (fixed) + drawing tools + cutout in user order among those customizable items (**cutout participates in order with drawing tools**).
3. Trailing: Save as if enabled + Done (fixed).

Bottom: enabled actions in `bottomActionOrder` (Cloud still gated by runtime config / existing QA cloud enable as today).

## Runtime wiring

- `AnnotateToolbarView` / `AnnotateBottomBarView`: observe Annotate store.
- Inline: effective drawing tools from store order/enable.
- If active tool becomes disabled → `.selection`.
- Shortcut prefs remain independent.

## Config import/export

Add `[annotate.chrome]` order/enabled mirroring Quick Access TOML style when low-cost; else UserDefaults-only + follow-up note.

## Tests

- `AnnotateChromeConfigurationStoreTests` (defaults, reorder, enable, always-on lock, normalization)
- Prefer a small test or compile-time guarantee that QA customization still builds against the shared list (manual QA prefs smoke is required)
- Optional: disabling `.watermark` drops it from effective drawable helper

## Scope

**In scope:**

- **Extract** `PreferencesReorderToggleList` (+ row) and **migrate Quick Access list section** onto it
- `AnnotateChromeItem` + `AnnotateChromeConfigurationStore`
- Annotate Preferences sections using the shared list
- `AnnotateToolbarView`, `AnnotateBottomBarView`, inline drawable consumers
- PreferencesKeys + L10n
- Config import/export if low-cost
- Tests + docs + `plans/README.md`

**Out of scope:**

- Card slot positioning for Annotate
- Redesigning Quick Access card preview / swipe UI (only list extract/adopt)
- Customizing zoom / pan / mode tabs / Drag to app
- Making Selection/Undo/Redo/Done hideable
- Merging with shortcut-disable prefs into one UI
- VideoEditor toolbars

## Steps

### Step 1: Extract `PreferencesReorderToggleList` / row

Move drag-handle + toggle row chrome out of QA private types. Keep QA-specific drag UTTypes/slot body drag in QA adapters or accessories.

**Verify:** Quick Access Preferences still compiles; list reorder/toggle still work manually or via existing tests if any.

### Step 2: Adopt shared list in Quick Access

Refactor `QuickAccessActionCustomizationView` list section to the shared component; accessory = placement badge. Preserve Reset Actions behavior.

**Verify:** No visual/behavior regression on Quick Actions list + card slot assignment.

### Step 3: Annotate model + store + keys + store tests

### Step 4: Annotate Preferences sections (shared list) + Reset chrome

### Step 5: Wire toolbar + bottom bar + inline + active-tool fallback

### Step 6: Config import/export (if applicable)

### Step 7: Docs + format + `./scripts/run-tests.sh --skip-visual`

## Done criteria

- [ ] Shared `PreferencesReorderToggleList` exists and is used by **both** Quick Access and Annotate
- [ ] Quick Access list behavior preserved (reorder, toggle, badges, reset; card slots still work)
- [ ] User can reorder/disable Annotate toolbar + bottom customizable items
- [ ] Selection, Undo, Redo, Done always visible
- [ ] No Annotate card-slot UI
- [ ] Runtime toolbar/bottom/inline honor Annotate store; disabled active tool → Selection
- [ ] Reset restores Annotate chrome defaults
- [ ] Tests pass; README 069 updated

## STOP conditions

- Extract would require rewriting QA slot drag in a way that breaks card assignment — STOP and report before shipping Annotate-only fork.
- Request to hide Done or Selection — conflicts with decision 3; STOP.
- Card preview/slots demanded for Annotate — out of scope; STOP.
- Inline annotate cannot share store without Capture rewrite — STOP and report call sites.

## Maintenance notes

- New drawing tools: add to `AnnotateChromeItem`, defaults, L10n, and shared list metadata.
- New prefs lists elsewhere should prefer `PreferencesReorderToggleList` over new private rows.
- Reviewer: (1) QA Preferences reorder/toggle/badge/slot smoke, (2) Annotate disable Watermark+Cloud, reorder Note before Rectangle, (3) Reset both surfaces.
