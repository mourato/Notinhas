# Plan 032: Roll OverlayTooltip across Annotate toolbar tools and chrome

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat df25f56f..HEAD -- Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift Notinhas/Features/Annotate/Services/AnnotateOverlayTooltipKeys.swift`
> If Plan 031 has already landed, re-read `AnnotateOverlayTooltipKeys` and
> `AnnotateToolbarView` against HEAD before editing. On excerpt mismatch that
> blocks the steps, STOP and report.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/031-annotate-overlay-tooltip-keys.md
- **Category**: direction (discoverability)
- **Planned at**: commit `df25f56f`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — shares OverlayTooltipPresenter singleton with 033
- **Reviewer required**: `yes` — hover lifecycle across many toolbar controls
- **Rationale**: Touches primary Annotate chrome; VoiceOver labels must stay
  correct when replacing `.help`.
- **Escalate when**: InlineAreaAnnotateWindow or Mockup toolbars are pulled into
  scope, or shortcuts for Done/Save As need new configurable bindings.

## Why this matters

The image editor is the primary Notinhas workspace. Designers already see
Arc-like keycap tooltips on the Notinhas note tool and note editor, but every
other toolbar control still uses plain `.help(displayName)` — even though
single-key shortcuts (V/R/A/…) and ⌘Z/⌘⇧Z/⌘B/⌘S/⌘⇧S are live. Expanding
OverlayTooltip here is the highest-leverage discoverability win for the product
loop in `AGENTS.md`.

## Current state

- Plan 031 adds `AnnotateOverlayTooltipKeys.toolKeys` / `actionKeys` and
  refactors the note button to use them. **Do not reimplement key arrays.**
- Toolbar tools still use `.help`:

```197:207:Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift
  private func annotationToolButton(for tool: AnnotationToolType, help: String? = nil) -> some View {
    ToolbarButton(
      icon: tool.icon,
      isSelected: state.selectedTool == tool
    ) {
      state.activateTool(tool)
    }
    .help(help ?? tool.displayName)
    ...
  }
```

(Confirm exact body at HEAD after 031.)

- Undo/redo / sidebar / crop use `.help` without keycaps
  (`AnnotateToolbarView.swift` ~85–221).
- Done / Save As have **no** hover hint (`~249–258`) despite ⌘S / ⌘⇧S in
  `AnnotateWindow`.
- Crop Apply / Cancel lack hover hints; window handles ↩ / Esc.
- Product intent: speed + precise visual handoff — do not expand into Video
  Editor or Preferences in this plan.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift` | exit 0 |
| Tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AnnotateOverlayTooltipKeysTests` | exit 0 |
| Build smoke | `./scripts/build_and_run.sh --no-video-module` | app builds and launches (manual hover check below) |

## Suggested executor toolkit

- Skills: `macos-app-engineering`, `accessibility-audit`, `apple-design`,
  `localization`, `plan-execute-review`.
- Manual smoke: open a capture → Annotate → hover Rectangle, Undo, Done and
  confirm keycap bubble appears / dismisses.

## Scope

**In scope**:
- `Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift`
- Accessibility labels on the same controls if they currently depend on `.help`
  alone — keep VoiceOver text via `.accessibilityLabel` where needed (mirror
  `notinhasNoteAccessibilityLabel` pattern)
- `plans/README.md` status (unless reviewer maintains index)

**Out of scope**:
- `AnnotateBottomBarView` (plan 033)
- Inline area annotate rail, Mockup toolbar, Preferences, VideoEditor
- Changing shortcut bindings or `AnnotateShortcutManager` defaults
- Slider steppers
- Removing the global shortcut overlay (⌘⇧K)

## Git workflow

- Branch: `advisor/032-annotate-toolbar-overlay-tooltips`
- Commit: `feat(annotate): show overlay shortcut tooltips on toolbar tools`
- Merge → cleanup → push per `plan-execute-review`.

## Steps

### Step 1: Confirm Plan 031 helper is available

```bash
test -f Notinhas/Features/Annotate/Services/AnnotateOverlayTooltipKeys.swift \
  && rg -n "toolKeys|actionKeys" Notinhas/Features/Annotate/Services/AnnotateOverlayTooltipKeys.swift
```

**Verify**: file exists; both helpers present. If missing, STOP — 031 not done.

### Step 2: Annotation tool buttons

In `annotationToolButton(for:)`:

- Replace `.help(help ?? tool.displayName)` with:

```swift
.overlayTooltip(
  help ?? tool.displayName,
  keys: AnnotateOverlayTooltipKeys.toolKeys(for: tool, manager: annotateShortcutManager),
  edge: .below
)
.accessibilityLabel(
  accessibilityTitle(help ?? tool.displayName, keys: AnnotateOverlayTooltipKeys.toolKeys(for: tool, manager: annotateShortcutManager))
)
```

Add a tiny private helper for VoiceOver (same spirit as note tool):

```swift
private func accessibilityTitle(_ title: String, keys: [String]) -> String {
  guard let first = keys.first else { return title }
  // For multi-part action keys joined for speech:
  let shortcut = keys.joined(separator: "")
  return L10n.Common.withShortcut(title, shortcut)
}
```

For single-key tools, `keys` has one element — fine. Do **not** stack `.help`
and `.overlayTooltip` on the same control.

Special case: `.notinhasNote` already has its own button with secondary gesture
hint — leave `notinhasNoteButton` as the sole path for that tool (it is not
created via `annotationToolButton`).

**Verify**: compile via focused build or full `build_and_run` later.

### Step 3: Crop, sidebar, undo, redo

Replace `.help` with `.overlayTooltip`:

| Control | Title | Keys |
|---------|-------|------|
| Crop | `L10n.AnnotateUI.crop` | `toolKeys(for: .crop)` |
| Sidebar | `L10n.AnnotateUI.toggleSidebar` | `actionKeys(for: .toggleSidebar)` |
| Undo | `L10n.Common.undo` | `["⌘", "Z"]` |
| Redo | `L10n.Common.redo` | `["⌘", "⇧", "Z"]` |

Use hard-coded keycap arrays for undo/redo — they are window-level, not in
`AnnotateShortcutManager`. Keep `.disabled` / opacity behavior unchanged.
Add `.accessibilityLabel` with `L10n.Common.withShortcut` when keys non-empty.

**Verify**: no `.help(` remains on these four controls in the file.

### Step 4: Done and Save As

On the Done / Save As buttons in `annotateActionButtons`:

```swift
.overlayTooltip(L10n.Common.saveAs, keys: ["⌘", "⇧", "S"], edge: .below)
...
.overlayTooltip(L10n.Common.done, keys: ["⌘", "S"], edge: .below)
```

Add matching accessibility labels. Do not invent new L10n keys unless strings
are missing (reuse `L10n.Common.*`).

**Verify**: both buttons have overlay tooltips; no `.help` added.

### Step 5: Crop Apply / Cancel / Restore

In `cropActionButtons`:

| Button | Keys |
|--------|------|
| Apply | `["⏎"]` |
| Cancel | `["esc"]` |
| Restore original | `[]` (title only) — keep existing help text as title |

Match keycap casing used in `NotinhasNoteEditorView` (`["esc"]`, `["⌘","⏎"]`).

**Verify**: `rg "\\.help\\(" Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift`
returns only intentional leftovers (e.g. combine picker / cutout if still
without shortcuts) — not tool/undo/sidebar/done/crop action rows.

### Step 6: Format, test, manual smoke, integrate

- `swiftformat` on the file
- Run AnnotateOverlayTooltipKeysTests
- Manual: hover Rectangle → see `R` keycap; hover Done → `⌘` `S`; mouse out
  dismisses
- Commit / merge / cleanup / push

## Test plan

- No new XCTest required beyond 031 helpers (UI hover is AppKit/SwiftUI).
- Optional: if a pure function extracts fixed chrome key arrays, unit-test that
  map — not required.
- Manual smoke is part of done criteria for this plan.

## Done criteria

- [ ] Every drawable tool button reachable via `annotationToolButton` uses
  `overlayTooltip` with `AnnotateOverlayTooltipKeys.toolKeys`
- [ ] Crop, sidebar, undo, redo, Done, Save As, crop Apply/Cancel use
  `overlayTooltip` (Restore may be title-only)
- [ ] No dual `.help` + `.overlayTooltip` on those controls
- [ ] Notinhas note button still shows secondary gesture hint
- [ ] `swiftformat` exit 0; focused keys tests pass
- [ ] Manual hover smoke noted in commit/NOTES
- [ ] Merged and pushed

## STOP conditions

- Plan 031 helper missing.
- `ToolbarButton` does not forward hover to modifiers (tooltip never shows) —
  STOP and report; do not wrap in a second hover layer without evidence.
- Accessibility regresses (VoiceOver loses tool name) — fix before merge.
- Scope creep into bottom bar or Preferences.

## Maintenance notes

- When a new `AnnotationToolType` gains a default shortcut, toolbar adoption is
  automatic via `toolKeys`.
- If undo/redo become user-configurable later, switch hard-coded arrays to
  manager lookups.
- Reviewer: watch for competing tooltips when two toolbar items sit close —
  presenter is a singleton (last show wins).
