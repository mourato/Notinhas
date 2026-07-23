# Plan 046: Restore All-In-One resize cursors over frozen backdrops

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 117bc733..HEAD -- Notinhas/Features/Capture/AllInOne/AllInOneFrozenBackdropHost.swift Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift NotinhasTests/Services/Capture/CaptureSelectionSnappingTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: `plans/042-smart-selection-resize-snapping.md`, `plans/045-freeze-all-displays-and-all-in-one.md`
- **Category**: bug
- **Planned at**: commit `117bc733`, 2026-07-22

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — window-level ordering, cursor-rect delivery, frozen pixels, and refinement overlays must be verified as one AppKit interaction path.
- **Reviewer required**: `yes` — the likely fix changes WindowServer stacking around a full-screen panel and must include a physical cursor/manual gate.
- **Rationale**: The level adjustment is small and deterministic, but the reported behavior depends on AppKit cursor rectangles and WindowServer state that XCTest cannot fully simulate. A focused test can prevent level regression, while manual validation proves the user-visible cursor behavior.
- **Escalate when**: The fix requires changing classic area selection, Recording/Scrolling capture semantics, capture result types, Screen Recording permission flow, or a second full-screen overlay host.

## Why this matters

After Plan 045 introduced a full-screen frozen backdrop for All-In-One refinement, the selection remains visible but the mouse no longer changes to the diagonal resize cursors at the rectangle corners. The resize geometry and cursor mapping still exist; the regression is most strongly associated with the frozen backdrop and selection overlays sharing `NSWindow.Level.floating`. macOS gives higher precedence to window levels, and `ignoresMouseEvents` makes a window transparent to mouse events but does not establish a separate cursor-rect routing contract. The result should preserve the frozen frame while restoring all eight native resize affordances.

## Current state

### Frozen backdrop and refinement ordering

- `Notinhas/Features/Capture/AllInOne/AllInOneFrozenBackdropHost.swift:12–27` creates one opaque, full-screen `NSPanel` per display, sets `ignoresMouseEvents = true`, and currently uses `level = .floating`.
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift:96–107` shows the frozen backdrop before refinement when a last rectangle exists. `:142–143` does the same after the initial selection completes. `:189–192` owns the host presentation.
- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift:120–125` creates one `RecordingRegionOverlayWindow` per screen, enables interaction, then calls `orderFrontRegardless()`.
- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift:85–101` also uses `level = .floating`; `:140–148` turns on interaction by clearing `ignoresMouseEvents` and calling `refreshCursor()`.

The important current sequence is therefore:

1. Full-screen frozen panel is ordered at `.floating`.
2. Selection overlay is ordered later at `.floating`.
3. The overlay registers cursor rectangles and dynamic cursor tracking.

The selection overlay should remain above the frozen pixels, but the backdrop must have a distinct level below the selection overlay level so AppKit does not have to arbitrate cursor ownership between equal-level full-screen panels.

### Cursor implementation and existing coverage

- `RecordingRegionOverlayView.resetCursorRects()` at `:280–301` registers a crosshair fallback, an open-hand selection rect, and eight resize-handle rects.
- `RecordingRegionOverlayView.cursorUpdate(with:)`, `mouseEntered(with:)`, and `refreshCursor()` at `:260–315` dynamically select the cursor from `handleAt(point:)`.
- `RecordingResizeHandleCursorGeometry` is already covered by `NotinhasTests/Services/Capture/CaptureSelectionSnappingTests.swift:291–305`; the tests prove corner priority and non-empty hit rectangles, not real WindowServer cursor delivery.
- `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift:102–117` already proves that refinement uses the frozen backdrop cache rather than starting a live backdrop task.

### Repository conventions to preserve

- Keep UI/AppKit changes on the main actor and keep the host narrow; do not rework upstream capture windows merely to match this fix (`AGENTS.md`).
- Use synthetic images and injected seams in XCTest; real cursor movement and capture overlays remain a manual visual gate (`.agents/skills/testing-xctest/SKILL.md` and `.agents/skills/delivery-workflow/SKILL.md`).
- New files under `Notinhas/` and `NotinhasTests/` are target-visible through the synchronized Xcode groups; no manual project-file entry is expected.
- Use SwiftFormat with the repository's `.swiftformat` configuration and Conventional Commit style if committing.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Drift | `git diff --stat 117bc733..HEAD -- <in-scope paths>` | No unexpected in-scope drift, or drift is reviewed and reported before implementation. |
| Cursor/geometry tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/CaptureSelectionSnappingTests` | Existing handle geometry tests and any new cursor-contract tests pass. |
| All-In-One tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` | Frozen-backdrop/refinement tests pass. |
| Format | `swiftformat Notinhas/Features/Capture/AllInOne/AllInOneFrozenBackdropHost.swift Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift NotinhasTests/Services/Capture/CaptureSelectionSnappingTests.swift` | exit 0; only scoped files are formatted. |
| Default build | `./scripts/build_and_run.sh --no-video-module` | The default Notinhas app builds and launches. |
| Full default tests | `./scripts/run-tests.sh --skip-visual` | Suite passes, with any known baseline/environment failures recorded separately. |

## Scope

**In scope (modify only these files unless a focused test needs one new file):**

- `Notinhas/Features/Capture/AllInOne/AllInOneFrozenBackdropHost.swift` — assign the frozen backdrop a level strictly below the selection overlay's `.floating` level while retaining its screen coverage and mouse transparency.
- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift` — preserve or explicitly reassert overlay ordering/cursor refresh after the backdrop is presented, only if required by the chosen level fix.
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` — touch only if a narrow ordering hook is required; do not change session ownership or mode dispatch.
- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift` — touch only if the focused cursor-refresh seam needs hardening; preserve behavior for Recording and Scrolling.
- `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift` — add a deterministic assertion for the host/overlay ordering contract if a testable seam is introduced.
- `NotinhasTests/Services/Capture/CaptureSelectionSnappingTests.swift` — extend only the existing geometry contract if the implementation changes cursor-rect geometry; do not duplicate current hit-rect tests.
- `plans/README.md` — add/update the plan status row.

**Out of scope:**

- `Notinhas/Features/Capture/AreaSelectionWindow.swift` and classic ⌘⇧4 selection behavior.
- Any change to the selected rectangle geometry, snapping candidates, aspect-ratio logic, minimum size, or crop/output behavior.
- Replacing the frozen backdrop with a live capture or removing Freeze Screen from All-In-One.
- Changing the backdrop to `.mainMenu`, `.screenSaver`, or another broad level merely to force visibility.
- Adding global event monitors, Accessibility prompts, or cursor polling loops as a workaround.
- Rewriting the shared overlay window or altering Recording/Scrolling behavior without a focused regression test and an explicit scope update.

## Steps

### Step 1: Add a deterministic window-level contract

Introduce the narrowest testable representation of the intended stacking rule. The frozen backdrop level must be created from a raw value strictly below `NSWindow.Level.floating`, for example `NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue - 1)`. Keep the selection overlay at `.floating`; do not depend on presentation order alone to express the relationship.

Expose only an internal/static value needed by tests, or use the project's existing test seam conventions. Add a test that asserts the backdrop level is lower than the selection overlay level and higher than `.normal` when the platform's standard level ordering permits that assertion. If the platform does not guarantee the intermediate level's relation to `.normal`, test only the required strict inequality with `.floating` and document the observed runtime ordering.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` → the new ordering test and existing All-In-One tests pass.

### Step 2: Apply the level fix without changing frozen pixels or input behavior

Set each `BackdropPanel` to the new level. Retain `isOpaque`, the per-display frame, `.canJoinAllSpaces`, `.fullScreenAuxiliary`, `.stationary`, `ignoresMouseEvents = true`, and the existing `NSImageView` image construction. Do not alter the frozen session or capture timing.

After the host is presented, ensure each refinement overlay remains ordered above it and has its cursor state refreshed after it becomes frontmost. Prefer a small, explicit ordering/refresh call over global cursor polling. If `makeRegionOverlay` is adjusted, preserve the existing `setInteractionEnabled(true)` contract and verify that `RecordingRegionOverlayWindow` still receives mouse-down/drag/resize events.

**Verify**: `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests -only-testing:NotinhasTests/CaptureSelectionSnappingTests` → all selected tests pass; `git diff --check` → no whitespace errors.

### Step 3: Add only the missing regression coverage

Keep the existing pure geometry tests for all eight handles. Add coverage only for behavior introduced by this fix:

- the frozen backdrop's declared level is below the selection overlay level;
- the refinement path still uses the frozen cache and does not start a live backdrop task;
- if a cursor-refresh/order seam is extracted, its state transition leaves the overlay interactive and requests a cursor refresh after ordering.

Do not write a test that asserts a specific `NSCursor` object from a headless XCTest process; the actual cursor arbitration is WindowServer/AppKit behavior and is explicitly a manual gate in the testing skill.

**Verify**: the focused test commands in the Commands table pass, with the new test count and names reported by the runner.

### Step 4: Run formatting, build, automated suite, and manual cursor gate

Run the format, default build, focused tests, and full default test commands. Then manually exercise the installed debug app with Screen Recording and Accessibility permissions available:

1. Activate All-In-One with Freeze Screen enabled and a valid selection.
2. Move the pointer slowly to each corner: top-left, top-right, bottom-left, and bottom-right. Confirm the diagonal resize cursor appears before pressing the mouse button.
3. Repeat for all four edges and confirm horizontal/vertical resize cursors.
4. Move outside the selection and confirm the crosshair returns; move inside the selection body and confirm the open-hand cursor remains.
5. Resize across a display boundary if using multiple monitors; confirm cursor behavior does not disappear when crossing screens.
6. Cancel and reopen All-In-One; confirm the cursor is restored to the arrow after teardown and the next session can show resize cursors again.
7. Run one classic area-selection smoke check and, if the Video module is available, one Recording/Scrolling smoke check to prove the shared overlay was not regressed.

Record automated results separately from the manual WindowServer result. Do not save screenshots, screen pixels, or permission data in the repository.

**Verify**: `./scripts/build_and_run.sh --no-video-module` exits successfully; `./scripts/run-tests.sh --skip-visual` passes or reports only documented baseline failures; the manual checklist confirms all eight resize cursors and teardown behavior.

## Test plan

- Use `NotinhasTests/Services/Capture/CaptureSelectionSnappingTests.swift` as the pattern for deterministic handle geometry assertions.
- Use `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift` as the pattern for frozen-backdrop/refinement tests with synthetic `AreaSelectionBackdrop` values.
- Add one focused ordering-contract test if the level is exposed through a test seam; avoid constructing real full-screen panels in unit tests unless the test runner already has a safe visual-host fixture.
- Treat real cursor appearance, cursor switching, and WindowServer ordering as manual-only. `--skip-visual` is not sufficient evidence for this bug because it skips the surfaces being changed.

## Done criteria

- [ ] Frozen backdrop panels render above normal application windows but strictly below All-In-One selection overlays.
- [ ] All-In-One refinement remains visibly frozen and the selection rectangle remains visible.
- [ ] All eight resize handles show the expected native cursor before mouse-down.
- [ ] Crosshair, open-hand, edge-resize, and diagonal-resize transitions still work.
- [ ] Cursor state is restored after cancel/teardown and the next session works.
- [ ] Classic area selection and any enabled Recording/Scrolling overlay behavior remain unchanged.
- [ ] Focused tests, default build, and full default tests pass, with baseline failures recorded separately.
- [ ] Manual WindowServer validation is recorded; no personal screen captures are committed.
- [ ] No files outside the in-scope list are modified, except an explicitly justified new test seam file.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

- Lowering the backdrop level makes frozen pixels disappear behind normal application windows or causes the selection to become invisible.
- The real cursor still remains an arrow after the level fix and the executor cannot identify a concrete AppKit ordering/refresh cause from the live window state.
- The fix requires changing `AreaSelectionWindow`, capture output, session preparation, or a public preference key.
- A shared `RecordingRegionOverlayWindow` change affects classic Area, Recording, or Scrolling behavior and no focused regression test can prove safety.
- The implementation proposes global mouse polling, a permanent global event monitor, an Accessibility prompt, or a live-capture fallback.
- Focused tests fail twice after a reasonable scoped correction, or the default build fails for an unrelated pre-existing environment issue; report the exact command and output instead of widening scope.
- Manual validation cannot distinguish the frozen backdrop from live pixels or cannot access the affected display; report the environment limitation instead of declaring the cursor gate passed.

## Maintenance notes

- Keep the backdrop level relationship explicit. Future full-screen All-In-One hosts must not reuse `.floating` unless they are intentionally above the selection overlay and have a documented cursor/input policy.
- Reviewers should inspect both window levels and the order/refresh sequence; a passing geometry test alone does not prove cursor delivery.
- If AppKit changes cursor-rect arbitration in a future macOS release, preserve the deterministic level test and repeat the physical cursor gate on the supported OS versions.
- This plan does not add screenshot-based UI automation because screen pixels and WindowServer cursor state are environment-specific and the repository's testing skill classifies them as manual checks.
