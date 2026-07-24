# Plan 061: Share All-In-One selection chrome with Capture Markup

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat c444ca35..HEAD -- \
>   Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift \
>   Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift \
>   Notinhas/Services/Capture \
>   NotinhasTests/Services/Capture \
>   NotinhasTests/Features/Annotate`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (soft: prefer landing after the session-wide All-In-One HUD
  cursor exclusion follow-up is committed if it is still local WIP)
- **Category**: tech-debt
- ****Planned at**: commit `c444ca35`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — shared chrome must land before Markup adoption
- **Reviewer required**: yes — visual parity across Recording / All-In-One / Markup
  selection chrome; hit geometry regressions are easy to miss
- **Rationale**: Touches shared Recording overlay drawing and Capture Markup
  SwiftUI selection chrome; behavior must stay identical for Recording/AIO while
  Markup appearance changes intentionally.
- **Escalate when**: Tempted to merge `InlineAreaAnnotatePanel` into
  `RecordingRegionOverlayWindow`, or to port aspect lock / snapping into Markup.

## Why this matters

Capture Markup and All-In-One both show a refinable selection rectangle, but they
draw different borders/handles and use different hit/cursor helpers. All-In-One
already reuses `RecordingRegionOverlayWindow` with Recording. Product wants the
same componentization for Markup: **adopt All-In-One (Recording) visual + L-handles
+ resize hit/cursors**, without unifying session hosts and without bringing
aspect lock or snapping into Markup.

Grill decision (2026-07-24): hosts stay separate because they mix visual with
session/interaction policy; extract a shared **selection chrome** module and
point both AppKit (Recording/AIO) and SwiftUI (Markup) at it.

## Current state

Canonical visual source (All-In-One / Recording):

- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift` —
  AppKit overlay: dim fill, optional continuous border (`drawsContinuousBorder`),
  L-corner + edge handles (`drawRecordingResizeHandles`), hit geometry
  (`RecordingResizeHandleCursorGeometry`), resize cursors.
- All-In-One refinement constructs the same window class via
  `AllInOneSelectionRefinementController` (already shared with Recording).

Markup-local parallel chrome:

- `Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift` —
  SwiftUI `selectionBorder` (continuous white `strokeBorder` 1.5),
  `InlineAreaResizeHandlesOverlay`, `InlineAreaResizeHandleChrome`,
  `InlineAreaResizeHandle` / hit targets / `InlineAreaResizeCursor`.
- Session host (`InlineAreaAnnotateCoordinator` / panel / selecting→annotating)
  stays Markup-owned.

Load-bearing excerpts as of `c444ca35`:

```swift
// RecordingRegionOverlayWindow.swift — AIO refinement typically omits continuous border
func setDrawsContinuousBorder(_ drawsContinuousBorder: Bool) { ... }

private func drawRecordingResizeHandles(for rect: CGRect) {
  drawCornerHandle(at: CGPoint(x: rect.minX, y: rect.maxY), corner: .topLeft)
  // ... four corners + four edges
}

private let cornerHandleLength: CGFloat = 20.0
private let handleThickness: CGFloat = 3.0
private let handleHitSize: CGFloat = 10.0
```

```swift
// InlineAreaAnnotateWindow.swift — Markup-local metrics (to be replaced)
private enum InlineAreaResizeHandleChrome {
  static let borderWidth: CGFloat = 1.5
  static let hitSize: CGFloat = 24
  static let cornerLength: CGFloat = 20
  static let edgeLength: CGFloat = 24
  static let thickness: CGFloat = 3
}
```

Vocabulary (`CONTEXT.md`):

- **Chrome de seleção compartilhado** — métricas + geometria de handles L + hit
  rects + cursores de resize; não inclui aspect lock, snapping, freeze, nem
  ferramentas de anotar.
- Keep **hosts** separate: `RecordingRegionOverlayWindow` vs `InlineAreaAnnotate*`.

Repo conventions: Swift 5.9, two-space indent, 120-col `.swiftformat`, Conventional
commits, `PBXFileSystemSynchronizedRootGroup` (drop new files under
`Notinhas/Services/Capture/` — no pbxproj edits). Prefer pure CoreGraphics helpers
with XCTest characterization like `CaptureFloatingToolbarPlacementTests` /
`CaptureSelectionSnappingTests` (which already exercise
`RecordingResizeHandleCursorGeometry`).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Services/Capture Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift NotinhasTests/Services/Capture NotinhasTests/Features/Annotate` | exit 0 |
| Shared chrome tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureSelectionChromeTests` | exit 0 (new) |
| Hit geometry regression | `./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureSelectionSnappingTests` | exit 0 |
| Markup session helpers | `./scripts/run-tests.sh -only-testing:NotinhasTests/InlineAreaAnnotateSessionTests` | exit 0 |
| Manual | Capture Markup + All-In-One refinement side-by-side: same L-handles look; Markup still annotates; AIO still snaps/aspect-locks | visual pass |

## Suggested executor toolkit

- `.agents/skills/capture-annotate-export/SKILL.md` for Markup scope boundary
- `.agents/skills/testing-xctest/SKILL.md` for pure geometry tests
- Global `macos-app-engineering` + overlay when bridging AppKit draw ↔ SwiftUI Canvas

## Scope

**In scope**:

- Create shared module under `Notinhas/Services/Capture/` (suggested names — pick
  one coherent family and stick to it):
  - `CaptureSelectionChromeMetrics.swift` — lengths, thickness, hit size, colors,
    continuous-border policy defaults matching Recording/AIO refinement
  - `CaptureSelectionHandleGeometry.swift` — pure functions for corner/edge handle
    bar rects and hit rects (extract from `RecordingResizeHandleCursorGeometry` +
    drawCornerHandle math)
  - Optional thin drawers:
    - AppKit: helper used by `RecordingRegionOverlayView.drawRecordingResizeHandles`
    - SwiftUI: `Canvas`-friendly path/rect list consumed by Markup overlay
  - Shared resize-handle enum **or** typealias/adapter from
    `RecordingResizeHandle` / `InlineAreaResizeHandle` so hit/cursor maps stay one
  - Shared resize cursor factory matching Recording’s `cursorFor(handle:)`
    (including diagonal custom images if Recording uses them)
- Refactor `RecordingRegionOverlayWindow.swift` to call the shared geometry/drawer
  (behavior lock: existing Recording/AIO visuals unchanged)
- Update Markup `InlineAreaAnnotateWindow.swift` selecting/annotating selection
  chrome to:
  - Draw L-handles via shared geometry (All-In-One look)
  - **Remove** Markup’s continuous white `strokeBorder` selection outline when
    matching AIO refinement (`drawsContinuousBorder == false`)
  - Use shared hit sizes / handle hit targets
  - Use shared resize cursors
- Tests: characterize handle bar rects + hit rects; keep
  `CaptureSelectionSnappingTests` green (update imports/type names only if the
  geometry type is renamed — expectations must stay equivalent)
- `plans/README.md` status row

**Out of scope**:

- Unifying `InlineAreaAnnotatePanel` with `RecordingRegionOverlayWindow`
- Aspect lock / snapping in Markup
- Changing All-In-One HUD layout, materials, or cursor-exclusion policy
- Dim overlay alpha changes unless required for parity with Recording’s
  `dimColor` **and** called out in the commit message (default: keep each host’s
  existing dim path; only unify handle/border chrome)
- Capture Markup tool deck / properties / action rail visuals
- Committing unrelated WIP (e.g. HUD cursor session timer) unless the operator
  asks; if that WIP touches the same files, STOP and report

## Git workflow

- Branch: `advisor/061-shared-selection-chrome`
- Commits: `refactor: extract CaptureSelectionHandleGeometry`, then
  `feat: adopt shared selection chrome in Capture Markup` (or one commit if tiny)
- Do NOT push/PR unless instructed

## Steps

### Step 1: Characterize current Recording handle geometry in tests

Before moving code, add failing-or-passing characterization tests that lock:

- Corner L-bar rects for a known `CGRect` (use the same math Recording uses today)
- Edge handle rects
- Hit rects for all eight handles (`RecordingResizeHandleCursorGeometry`)

Place under `NotinhasTests/Services/Capture/CaptureSelectionChromeTests.swift`
(or extend snapping tests carefully). Prefer **new** file so Markup adoption stays
reviewable.

**Verify**:
`./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureSelectionChromeTests`
(and/or existing snapping handle tests) → pass against **current** Recording math.

### Step 2: Extract shared pure geometry + metrics

Move metrics + handle bar + hit geometry into `Notinhas/Services/Capture/` helpers
with no AppKit UIKit SwiftUI drawing dependency beyond `CoreGraphics` where
possible.

Refactor `RecordingRegionOverlayView` draw/hit paths to call the shared helpers.
**Do not** change numeric results: Step 1 tests must still pass without expectation
edits.

If `RecordingResizeHandleCursorGeometry` is relocated/renamed, update call sites
(Recording overlay, snapping tests, AIO if any).

**Verify**:
`./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureSelectionChromeTests -only-testing:NotinhasTests/CaptureSelectionSnappingTests`
→ exit 0; **no** expectation changes required.

### Step 3: Adopt shared chrome in Capture Markup

In `InlineAreaAnnotateWindow.swift`:

1. Replace `InlineAreaResizeHandlesOverlay` drawing with shared handle geometry
   (SwiftUI `Canvas` or `Path` from shared rects).
2. Remove continuous `selectionBorder` stroke for the live selection rectangle so
   Markup matches AIO refinement (handles only). Keep any annotate-phase affordances
   that are not the selection outline if they are unrelated — but the selection
   rect chrome must match AIO.
3. Point hit targets at shared hit size/rects (map `InlineAreaResizeHandle` ↔
   shared handle enum via a small adapter if needed).
4. Point resize cursors at the shared cursor factory (delete
   `InlineAreaResizeCursor` if fully superseded).

Do **not** change Markup gesture state machine, minimum selection size policy,
or annotate tool chrome.

**Verify**:
`swiftformat` on touched paths → exit 0  
`./scripts/run-tests.sh -only-testing:NotinhasTests/InlineAreaAnnotateSessionTests -only-testing:NotinhasTests/CaptureSelectionChromeTests`
→ exit 0

### Step 4: Manual visual gate

1. All-In-One refinement: L-handles look **unchanged** vs pre-plan; aspect lock +
   snapping still work.
2. Capture Markup selecting phase: selection shows **same L-handle language** as
   AIO (no thick continuous white outline); resize cursors match on corners/edges.
3. Capture Markup annotating still works (tools, notes, export path smoke).

**Verify**: manual checklist; note PENDING in README if environment blocks TCC.

## Test plan

- New `CaptureSelectionChromeTests` locking handle bar + hit geometry (Step 1–2).
- Existing `CaptureSelectionSnappingTests` remain green (rename-only if needed).
- `InlineAreaAnnotateSessionTests` remain green (no geometry contract there today).
- Manual dual-flow visual gate (Step 4).

## Done criteria

- [ ] Shared capture selection chrome module exists under `Notinhas/Services/Capture/`
- [ ] `RecordingRegionOverlayView` draws/hits via shared helpers (no duplicated L-handle math)
- [ ] Capture Markup selection chrome matches AIO L-handles; continuous Markup
      selection outline removed
- [ ] Markup uses shared hit sizes + resize cursors
- [ ] Focused XCTest commands above exit 0 without changing Step 1 numeric
      expectations (except intentional Markup visual tests if added)
- [ ] No aspect lock/snapping added to Markup; hosts not merged
- [ ] `plans/README.md` 061 status updated

## STOP conditions

Stop and report back (do not improvise) if:

- Recording/AIO handle tests require expectation changes after “behavior-preserving”
  extraction (math drifted).
- Uncommitted local WIP on the same files conflicts (especially AreaSelection /
  HUD cursor follow-up) — ask operator how to sequence.
- Scope pressure to unify hosts or port snapping/aspect lock into Markup.
- SwiftUI coordinate space makes shared AppKit-origin handle math incorrect in
  Markup — stop and report rather than inventing a second geometry.
- Verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Future selection chrome tweaks (thickness, L length, hit size) land in the shared
  module only — both Recording/AIO and Markup should pick them up.
- Reviewers: confirm Markup no longer draws a continuous selection stroke; confirm
  Recording video `hideBorder()` path still hides handles/border as before.
- Deferred: shared dim fill; host unification; Markup aspect lock/snapping.
