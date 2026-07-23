# Plan 056: Stabilize the Notinhas contextual editor placement (stop tremble)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 84be0955..HEAD -- Notinhas/Features/Notinhas/Views/NotinhasNoteEditorCanvasOverlay.swift Notinhas/Features/Notinhas/Services/NotinhasNoteEditorPanelPlacement.swift Notinhas/Features/Notinhas/Services/NotinhasNoteGeometry.swift Notinhas/Features/Annotate/Components/AnnotateCanvasView.swift NotinhasTests/Features/Notinhas/NotinhasNoteEditorInteractionTests.swift NotinhasTests/Features/Notinhas/NotinhasNoteGeometryTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED — touches SwiftUI overlay placement that plan 052 just introduced; wrong clamp policy can leave the box clipped or fight the drag gesture.
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `84be0955`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent of plan 057 (drawing-view hitch) and plan 058 (Quick Access); do not edit those plans' in-scope files.
- **Reviewer required**: `yes` — visual jitter / layout feedback loops are easy to miss in unit tests alone.
- **Rationale**: Scope is narrow (placement state + overlay hooks) but requires judgment about when to reclamp vs preserve a drag origin; not a mechanical Low/Fast change.
- **Escalate when**: the fix appears to require persisting panel position, changing export/render trees, rewriting `AnnotateState` viewport metrics globally, or replacing the SwiftUI editor with an `NSPanel`.

## Why this matters

After plan 052 made the contextual Notinhas editor freely draggable, dragging that box (and sometimes leaving it idle) can make it tremble or oscillate by ~1px as if competing layout passes are rewriting its origin. That breaks trust in the annotate → notes handoff loop. This plan removes the feedback that fights the user's drag and the idle clamp oscillation, without changing note data, export, or the side-panel summary.

## Current state

Vocabulary (from `CONTEXT.md` / plan 052): the **caixa contextual de edição** is the floating editor on the canvas; the **painel lateral de resumo** is out of scope; panel position is **transient UI state** (not persisted).

Relevant files:

- `Notinhas/Features/Notinhas/Views/NotinhasNoteEditorCanvasOverlay.swift` — hosts the editor; seeds / reclamps placement; wires drag.
- `Notinhas/Features/Notinhas/Services/NotinhasNoteEditorPanelPlacement.swift` — transient origin + drag anchor.
- `Notinhas/Features/Notinhas/Services/NotinhasNoteGeometry.swift` — `editorOrigin`, `editorPanelSize`, `clampedEditorPanelOrigin`.
- `Notinhas/Features/Annotate/Components/AnnotateCanvasView.swift` — hosts the overlay as a sibling of the zoom/pan group with `hostSize: containerSize`.
- `NotinhasTests/Features/Notinhas/NotinhasNoteEditorInteractionTests.swift` — pure placement tests (exemplar for new cases).

Smoking-gun excerpts:

`displayOrigin` **re-clamps on every layout read**, so a jittering `hostSize` / `panelSize` moves the visible origin even when the stored `origin` is unchanged:

```21:33:Notinhas/Features/Notinhas/Services/NotinhasNoteEditorPanelPlacement.swift
  func displayOrigin(
    selectionBounds: CGRect,
    panelSize: CGSize,
    in containerBounds: CGRect,
    margin: CGFloat = 12
  ) -> CGPoint {
    if let origin {
      return NotinhasNoteGeometry.clampedEditorPanelOrigin(
        origin,
        panelSize: panelSize,
        in: containerBounds,
        margin: margin
      )
    }
```

Overlay hooks reclamp whenever `panelSize` or `hostSize` changes — including mid-drag:

```85:90:Notinhas/Features/Notinhas/Views/NotinhasNoteEditorCanvasOverlay.swift
      .onChange(of: panelSize) { _ in
        panelPlacement.reclamp(panelSize: panelSize, in: workArea)
      }
      .onChange(of: hostSize) { _ in
        panelPlacement.reclamp(panelSize: panelSize, in: workArea)
      }
```

`editorPanelSize` returns a **preferred max height** (200/280), while the SwiftUI view uses `.fixedSize(vertical: true)` and may be shorter — clamp math can disagree with the painted box when sizes flicker:

```137:152:Notinhas/Features/Notinhas/Services/NotinhasNoteGeometry.swift
  static func editorPanelSize(
    isRectangular: Bool,
    in containerBounds: CGRect,
    ...
  ) -> CGSize {
    ...
    let preferredHeight = isRectangular ? preferredRectHeight : preferredPointHeight
    let height = min(preferredHeight, maxHeight)
    return CGSize(width: width, height: height)
  }
```

Plan 052 already required: retain origin after first seed; reclamp on real size changes; do not persist position; do not put the editor in the export tree.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Focused placement tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteEditorInteractionTests` | Exit 0 |
| Focused geometry tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteGeometryTests` | Exit 0 |
| Default suite without visual flashes | `./scripts/run-tests.sh --skip-visual` | Exit 0 |
| Debug build | `xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO` | Exit 0 |
| Diff hygiene | `git diff --check` | Exit 0 |
| Format (if Swift touched) | `swiftformat Notinhas/Features/Notinhas NotinhasTests/Features/Notinhas` | Exit 0; match `.swiftformat` |

Do **not** enable the Video module for this plan.

## Suggested executor toolkit

- `.agents/skills/capture-annotate-export` — keep editor UI out of export/clipboard.
- `macos-app-engineering` (global) + overlay if present — SwiftUI hosting / GeometryReader pitfalls.
- `.agents/skills/testing-xctest` — extend interaction tests in the existing pure-helper style.
- `swift-conventions` — naming / formatting.

## Scope

**In scope** (modify only these):

- `Notinhas/Features/Notinhas/Services/NotinhasNoteEditorPanelPlacement.swift`
- `Notinhas/Features/Notinhas/Views/NotinhasNoteEditorCanvasOverlay.swift`
- `Notinhas/Features/Notinhas/Services/NotinhasNoteGeometry.swift` — only if a pure helper is needed for epsilon equality / “meaningful size change” (keep helpers pure and tested).
- `NotinhasTests/Features/Notinhas/NotinhasNoteEditorInteractionTests.swift`
- `NotinhasTests/Features/Notinhas/NotinhasNoteGeometryTests.swift` — only if a new pure helper is added.
- `plans/README.md` — status row for this plan.

**Out of scope**:

- `NotinhasNotesSidePanelView` / summary panel layout.
- `AnnotateState` persistence, undo, `NotinhasVisualNote` model, export/composer/renderer.
- `AnnotateCanvasDrawingView` drag hitch (plan 057).
- Quick Access (plan 058).
- All-In-One / plan 055 capture chrome.
- Converting the contextual editor into a separate `NSWindow`/`NSPanel`.

## Git workflow

- Branch: `implement/056-stabilize-notinhas-editor-placement` (match existing `implement/NNN-…` style).
- Conventional commits, e.g. `fix(notinhas): stop contextual editor placement tremble`.
- Do not push or open a PR unless the operator asks.

## Steps

### Step 1: Characterize placement against size/drag races (tests first)

Extend `NotinhasNoteEditorInteractionTests` (same style as existing cases) with pure tests that lock the intended contract:

1. **Idle stored origin is stable** when `displayOrigin` is called repeatedly with identical `panelSize` / container — same point every time.
2. **Sub-point container noise must not move a seeded origin** — call `displayOrigin` / `reclamp` with containers that differ by ≤ `0.5` pt (or the epsilon you introduce); origin must stay put. If you introduce `sizesAreEffectivelyEqual` / `shouldReclamp`, test that helper directly in geometry or placement tests.
3. **Active drag ignores reclamp** — after `beginDrag`, calling `reclamp` with a shrunk container must **not** change `origin` until `endDrag`; after `endDrag`, a real shrink **does** reclamp.
4. Preserve existing tests: retain-across-note-change, reset, begin/update/end drag math.

Implement the minimal API on `NotinhasNoteEditorPanelPlacement` to make (3) true (e.g. `isDragging` derived from `dragAnchorOrigin != nil`, and `reclamp` early-returns while dragging). Do **not** change product behavior of automatic first placement.

**Verify**: `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteEditorInteractionTests` → exit 0, including new cases.

### Step 2: Stop overlay hooks from fighting the drag / oscillating

In `NotinhasNoteEditorCanvasOverlay`:

1. Gate `onChange(of: panelSize)` and `onChange(of: hostSize)` so they call `reclamp` only when:
   - placement is **not** dragging, and
   - the size change is **meaningful** (epsilon / `sizesAreEffectivelyEqual`), not every float tick from `GeometryReader`.
2. Keep `ensureSeeded` on appear and `reset` on disappear.
3. Keep drag wiring (`beginDrag` / `updateDrag` / `endDrag`); do not attach a second source of truth for origin.
4. Do **not** write panel origin into `AnnotateState`.

If `panelSize` still uses preferred max height while the painted view is shorter, either:

- continue clamping with preferred size (acceptable if epsilon + drag-gate remove tremble), **or**
- pass a measured size into placement **only** if you can do so without a PreferenceKey feedback loop (STOP if a PreferenceKey/`GeometryReader` inside the editor causes another oscillation).

**Verify**: `xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO` → exit 0.

### Step 3: Format and focused regression

Run `swiftformat` on touched Swift paths, then re-run interaction (+ geometry if touched) tests.

**Verify**: `swiftformat Notinhas/Features/Notinhas NotinhasTests/Features/Notinhas` then focused test commands above → exit 0; `git diff --check` → exit 0.

### Step 4: Broader suite + manual Annotate gate

Run `./scripts/run-tests.sh --skip-visual`.

Manual gate (Screen Recording / Accessibility as needed for capture):

1. Capture → Annotate → create a point Notinha and open the contextual editor.
2. Drag the box slowly across open canvas space for ≥2 seconds — **no visible tremble / vibration**.
3. Leave the box idle for ≥3 seconds with the mouse still — **no ~1px idle oscillation**.
4. Resize the Annotate window — box reclamps into the work area **after** resize, without continuous jitter.
5. Drag near edges — hard clamp is OK; must not chatter along the edge.
6. Zoom/pan/mockup — box stays upright in UI space; still no idle shake.
7. Preview/copy — editor chrome still absent from export (plan 052 invariant).

**Verify**: suite exit 0; manual checklist above passes; `git status` shows only in-scope files.

## Test plan

- Add cases listed in Step 1 to `NotinhasNoteEditorInteractionTests.swift`.
- Model structure after existing tests in that file (`testBeginDragUsesSeededOriginAndEndDragClearsAnchor`).
- Do **not** add pixel snapshot tests for tremble.
- Optional: if a pure epsilon helper lands in `NotinhasNoteGeometry`, cover it in `NotinhasNoteGeometryTests`.

## Done criteria

- [ ] Dragging the contextual editor in open space shows no tremble (manual).
- [ ] Idle editor shows no ~1px oscillation (manual).
- [ ] `reclamp` is a no-op while a drag is active (unit-tested).
- [ ] Meaningless sub-point size noise does not move a seeded origin (unit-tested).
- [ ] Real window shrink still reclamps after drag ends (unit-tested + manual).
- [ ] No persistence / export / side-panel changes.
- [ ] `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteEditorInteractionTests` exits 0.
- [ ] `./scripts/run-tests.sh --skip-visual` exits 0.
- [ ] Debug build exits 0; `git diff --check` exits 0.
- [ ] Only in-scope files modified; `plans/README.md` status updated.

## STOP conditions

- Drift check shows in-scope files no longer match the excerpts and the new shape is unclear.
- Fix seems to require PreferenceKey / nested GeometryReader measurement that itself oscillates.
- Fix seems to require storing origin on `AnnotateState` or in the session sidecar.
- Fix seems to require changing `AnnotateCanvasView` zoom/pan hosting (beyond passing a stabilized size if absolutely necessary) — report before expanding scope.
- Any verification fails twice after a reasonable fix attempt.
- You discover tremble is actually the **marker** moving (plan 057 territory), not the contextual editor box — stop and report; do not “fix” marker drag here.

## Maintenance notes

- Future `onChange` hooks on `hostSize` / panel metrics must keep the drag-active and epsilon guards.
- Reviewers should watch for reintroduction of unconditional `displayOrigin` reclamping against noisy containers.
- Deferred: measuring true painted panel height for clamp (only if preferred-size clamp remains user-visible after this fix).
