# Plan 057: Remove annotate shape and Notinhas marker drag-start hitch

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat 84be0955..HEAD -- Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift Notinhas/Features/Notinhas/Annotate/NotinhasAnnotateState.swift Notinhas/Features/Annotate/AnnotateState.swift NotinhasTests/Features/Notinhas/NotinhasAnnotateStateTests.swift NotinhasTests/Features/Annotate`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED — AppKit canvas interaction + `@Published` invalidation; easy to regress selection chrome or multi-select drag.
- **Depends on**: none
- **Category**: bug / perf
- **Planned at**: commit `84be0955`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent of plan 056 (editor overlay placement) and plan 058 (Quick Access); do not edit those plans' in-scope files.
- **Reviewer required**: `yes` — hit-testing / layer-split / selection timing bugs are high-impact in Annotate.
- **Rationale**: Two related hitches share the canvas invalidation story but need careful AppKit/Combine changes; not Low/Fast.
- **Escalate when**: the fix requires rewriting the entire five-layer canvas compositor, changing export hit geometry, or abandoning gesture-local annotation buffers.

## Why this matters

In the Annotate editor, the first click-and-drag on a shape (rectangle, circle, arrow, …) feels like a freeze before the object follows the cursor. Notinhas **markers** (pins/rects) show the same start hitch when selected or moved. After the hitch, motion is usually smooth — so this is a start-of-interaction cost, not continuous tracking lag. Removing it makes annotate and Notinhas feel immediate again.

## Current state

Annotation drag already uses gesture-local copies to avoid per-event `@Published` mutation, but start still pays full redraws and a deferred selection publish:

```647:656:Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift
    if state.selectedTool != .crop,
       let annotation = hitTestAnnotation(at: imagePoint),
       !Self.shouldPrioritizeCanvasMarkup(over: annotation, selectedTool: state.selectedTool) {
      // Set local tracking synchronously to avoid race condition with mouseDragged
      beginAnnotationDrag(anchor: annotation, at: imagePoint)
      // Update state asynchronously (for UI reflection)
      Task { @MainActor in
        state.selectedAnnotationId = annotation.id
        state.selectedTool = annotation.type.toolType
      }
      return
    }
```

```697:730:Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift
  private func beginAnnotationDrag(anchor annotation: AnnotationItem, at imagePoint: CGPoint) {
    ...
    NSCursor.closedHand.set()
    invalidateDrawing()
  }
```

Selection publishers always force a **full** redraw:

```215:220:Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift
    state.$selectedAnnotationIds
      .sink { [weak self] _ in self?.invalidateDrawing() }
      .store(in: &stateObservers)
    state.$selectedAnnotationId
      .sink { [weak self] _ in self?.invalidateDrawing() }
      .store(in: &stateObservers)
```

Notinhas marker move mutates `@Published notinhasNotes` every drag frame, and that publisher also full-invalidates:

```212:214:Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift
    state.$notinhasNotes
      .sink { [weak self] _ in self?.invalidateDrawing() }
      .store(in: &stateObservers)
```

```98:112:Notinhas/Features/Notinhas/Annotate/NotinhasAnnotateState.swift
  func notinhasUpdateMovingNote(
    to imagePoint: CGPoint,
    imageBounds: CGRect,
    from startPoint: CGPoint
  ) {
    ...
    notinhasNotes[index].target = NotinhasNoteGeometry.translated(
      original,
      by: delta,
      within: imageBounds
    )
  }
```

Mouse-down on a marker also selects + `invalidateDrawing()` before any drag threshold (`handleNotinhasMouseDown` around lines 1260–1265).

Live-layer path exists (`invalidateLiveLayers` / `usesDragLayerSplit`) and should remain the per-frame path once a single-item drag is established.

Persistence (`saveState` / Notinhas undo checkpoint) already commits on mouse-up — do **not** move persistence onto the drag path.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Notinhas annotate state tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasAnnotateStateTests` | Exit 0 |
| Focused Annotate tests (if you add a class) | `./scripts/run-tests.sh -only-testing:NotinhasTests/<YourNewOrExistingClass>` | Exit 0 |
| Default suite without visual flashes | `./scripts/run-tests.sh --skip-visual` | Exit 0 |
| Debug build | `xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO` | Exit 0 |
| Diff hygiene | `git diff --check` | Exit 0 |
| Format | `swiftformat Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift Notinhas/Features/Notinhas/Annotate NotinhasTests/Features/Notinhas NotinhasTests/Features/Annotate` | Exit 0 |

Do **not** enable the Video module for this plan.

## Suggested executor toolkit

- `.agents/skills/capture-annotate-export` — marker move must not affect export composition semantics.
- `.agents/skills/swift-concurrency-expert` — keep UI/`AnnotateState` on MainActor; avoid introducing new races between `mouseDragged` and `Task` hops.
- `.agents/skills/testing-xctest` — prefer pure/state tests; avoid brittle UI snapshots.
- `code-quality` — prefer the narrowest invalidation fix over a broad rewrite.

## Scope

**In scope**:

- `Notinhas/Features/Annotate/Components/AnnotateCanvasDrawingView.swift`
- `Notinhas/Features/Notinhas/Annotate/NotinhasAnnotateState.swift` — only if marker move needs a gesture-local / non-publishing update API.
- `Notinhas/Features/Annotate/AnnotateState.swift` — only if a tiny helper must live on the AnnotateState extension for Notinhas (prefer extending `NotinhasAnnotateState.swift`).
- Tests under `NotinhasTests/Features/Notinhas/` and/or `NotinhasTests/Features/Annotate/` for the new seams.
- `plans/README.md` — status row.

**Out of scope**:

- Contextual editor tremble / `NotinhasNoteEditorCanvasOverlay` (plan 056).
- Quick Access hover (plan 058).
- Export/composer/renderer changes.
- Multi-select performance beyond “do not regress”; if multi-select still full-redraws per frame by design (`usesDragLayerSplit == false`), leave that path unless a tiny safe win appears.
- Rewriting crop, text editing, or combine/auto-stitch flows except where selection timing must stay consistent.

## Git workflow

- Branch: `implement/057-annotate-drag-start-hitch`.
- Commit style: `fix(annotate): remove drag-start hitch for shapes and notes`.
- Do not push or open a PR unless asked.

## Steps

### Step 1: Fix annotation selection timing at drag start

In `AnnotateCanvasDrawingView` mouse-down paths that call `beginAnnotationDrag`:

1. Apply toolbar/selection UI state **synchronously on the MainActor** before or as part of starting the drag (same run loop turn as `mouseDown`), **or** suppress `$selectedAnnotationId` / `$selectedAnnotationIds` → `invalidateDrawing()` while `isDraggingAnnotation` / `isResizingAnnotation` is true and rely on the drag-layer invalidate path instead.
2. Remove the deferred `Task { @MainActor in state.selectedAnnotationId = … }` pattern for the drag-start path if it still exists after your change — that Task landing mid-gesture is a primary hitch suspect.
3. Keep the comment intent (“local tracking before mouseDragged”) — local gesture buffers must still be set before the first `mouseDragged`.
4. Avoid **double** full `invalidateDrawing()` at start when one is enough for layer split (e.g. `beginAnnotationDrag` + selection sink). Target: at most one full invalidate to enter drag-layer split, then live-layer updates only for single-item drags.

**Verify**: Debug build exits 0. Manually smoke: select tool ≠ selection, click-drag a rectangle — object should follow immediately with no visible “stuck then jump” on the first pixels of movement.

### Step 2: Stop Notinhas marker moves from full-redrawing every frame

Choose the narrowest approach that preserves commit-on-mouse-up undo behavior:

**Preferred:** During an active move (`notinhasMovingNoteID != nil`), keep the live target in gesture-local state (drawing-view locals and/or a non-`@Published` field), draw from that in `drawNotinhasNotes`, and write `notinhasNotes` **once** on commit (existing `notinhasCommitMovingNote`). Cancel restores the original target (already implemented).

**Acceptable alternative:** Keep writing notes each frame but make the `$notinhasNotes` sink call `invalidateLiveLayers()` (or no-op) while `notinhasMovingNoteID != nil`, and ensure `drawNotinhasNotes` / live layers actually paint the moving note. Only use this if gesture-local drawing is clearly larger than needed — and STOP if live layers do not include Notinhas content today (inspect `liveLayerViews` / draw routing before choosing).

Also reduce mouse-down cost: selecting a marker should not force an expensive full redraw if a live invalidate suffices for selection chrome.

**Verify**: `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasAnnotateStateTests` → exit 0. Add/adjust tests for: move updates do not leave stale targets after commit/cancel; cancel restores original target.

### Step 3: Characterization tests for the invalidation contract

Add focused tests where seams are pure/state-level. Examples:

- `notinhasUpdateMovingNote` + commit/cancel still match current geometry rules (`NotinhasNoteGeometry.translated` / image bounds).
- If you expose a testable hook (e.g. “notes publisher should not fire during move” via a package-visible counter, or gesture-local target accessors), assert the contract. Prefer testing state behavior over AppKit view spies.
- Do **not** add flaky timing tests that sleep for “hitch duration”.

If no new Annotate XCTest class exists for drawing-view policy, put state tests next to `NotinhasAnnotateStateTests` and keep drawing-view changes covered by the manual gate.

**Verify**: focused Notinhas annotate tests exit 0; `git diff --check` exit 0.

### Step 4: Suite + manual gate

Run `./scripts/run-tests.sh --skip-visual`.

Manual Annotate gate:

1. Open a screenshot in Annotate.
2. Draw a rectangle, circle, and arrow. For each: click and immediately drag — **no start hitch**; follow feels immediate.
3. With the selection tool, drag a single selected shape — same.
4. Switch to Notinhas: click a pin/rect and drag past the move threshold — **no start hitch**; marker follows smoothly; release commits; Undo restores prior position if an undo checkpoint was created.
5. Click a marker without dragging — editor still opens (click-vs-move threshold preserved).
6. Multi-select drag (if easy): must not crash; per-frame full redraw for multi-select is acceptable if unchanged by design.

**Verify**: suite exit 0; manual checklist passes; only in-scope files in `git status`.

## Test plan

- Extend `NotinhasAnnotateStateTests` for move/commit/cancel (and any new non-publishing move API).
- Model after existing tests in that file.
- Manual gate is mandatory for the hitch itself (not unit-testable reliably without Instruments).

## Done criteria

- [ ] Single annotation drag-start shows no perceptible hitch (manual).
- [ ] Notinhas marker select/move shows no perceptible start hitch (manual).
- [ ] Single-item annotation drag does not full-`invalidateDrawing` on every `mouseDragged` event after start.
- [ ] Marker move does not full-invalidate via `$notinhasNotes` on every frame (gesture-local **or** gated sink — documented in the PR/commit body).
- [ ] Click-without-drag still opens the contextual editor; drag threshold unchanged (`shouldBeginMove`).
- [ ] Undo/cancel restore semantics preserved for marker moves.
- [ ] `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasAnnotateStateTests` exits 0.
- [ ] `./scripts/run-tests.sh --skip-visual` exits 0.
- [ ] Debug build + `git diff --check` exit 0.
- [ ] `plans/README.md` status updated; no plan 056/058 files touched.

## STOP conditions

- Live layers do not draw Notinhas content and the only fix would be a large compositor rewrite — stop and report with evidence (which layers call `drawNotinhasNotes`).
- Removing the selection `Task` breaks a documented race that cannot be fixed with synchronous MainActor updates — stop and report.
- Fix appears to require changing export / hit-testing geometry helpers used by composition.
- Drift mismatch on the cited mouse-down / publisher blocks.
- Verification fails twice after a reasonable attempt.

## Maintenance notes

- Any new `@Published` on Annotate/Notinhas move paths must not default to full-canvas invalidate during gestures.
- Reviewers: confirm multi-select and combine/auto-stitch still behave; confirm text-tool / crop paths untouched.
- Deferred: Instruments time-profile gate (optional follow-up; not required to close this plan).
