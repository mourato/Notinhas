# Plan 059: Restore arrow cursor over All-In-One floating HUDs

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5c30ed4b..HEAD -- \
>   Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift \
>   Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift \
>   Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift \
>   Notinhas/Services/Capture/FloatingToolbar \
>   NotinhasTests/Features/Capture \
>   NotinhasTests/Services/Capture`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `5c30ed4b`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: yes — independent of plan 060 (clamp helper)
- **Reviewer required**: no — pure geometry helper + narrow wiring; manual cursor smoke is enough
- **Rationale**: Deterministic fix with a unit-testable exclusion predicate and a small call-site change in the All-In-One refinement timer. Does not change HUD visuals, placement, or Capture Markup.
- **Escalate when**: Fix appears to require changing `RecordingRegionOverlayWindow.updateCursorFor`, making `CaptureFloatingHUDWindow` keyable, or rewriting Capture Markup / `AreaSelectionController` cursor ownership.

## Why this matters

During All-In-One selection refinement, mode and dimensions bars are separate
`CaptureFloatingHUDWindow` panels above a full-screen `RecordingRegionOverlayWindow`.
Clicks hit the HUD (higher window level), but a 60 Hz cursor timer treats any
pointer still inside the overlay’s full-screen frame as overlay territory and
force-sets `NSCursor.crosshair`. Users see a selection crosshair while hovering
clickable HUD buttons. Capture Markup does not have this bug because its chrome
lives in the same panel and does not run an external overlay cursor owner.

Product decision for this round (**infra reuse, distinct looks**): fix cursor
ownership for floating HUDs; do **not** unify Markup and All-In-One hosting or
button sizes.

## Current state

Relevant files:

- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift` —
  owns the 60 Hz cursor timer; calls `overlay.refreshCursor()` whenever
  `NSEvent.mouseLocation` is inside an overlay frame (full screen).
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` —
  owns `modeHUD` / `actionHUD`, positions them via `positionHUDs()`, creates
  the refinement controller in `beginRefinement(with:)`.
- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift` —
  `refreshCursor()` → `updateCursorFor` force-sets crosshair outside the
  selection rect (do **not** change this path in this plan).
- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingHUDWindow.swift` —
  `canBecomeKey == false`; no cursor rects; clicks still work at `.popUpMenu`.
- `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift` —
  existing coordinator/refinement tests; pattern for new pure-helper tests.
- `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift` —
  pure CoreGraphics-style tests for FloatingToolbar helpers (good structural
  pattern for the new exclusion tests).

Load-bearing excerpts as of `5c30ed4b`:

```swift
// AllInOneSelectionRefinementController.swift — timer ignores HUD frames
private func handleCursorTrackingTick() {
  guard !regionOverlayWindows.isEmpty else { return }

  if let ownerID = keyboardOwnerOverlayID,
     let owner = regionOverlayWindows[ownerID],
     owner.isGestureInProgress {
    owner.refreshCursor()
    return
  }

  let location = NSEvent.mouseLocation
  guard let overlay = regionOverlayWindows.values.first(where: { $0.frame.contains(location) }) else {
    NSCursor.arrow.set()
    return
  }
  // ... key ownership / else { overlay.refreshCursor() }
}
```

```swift
// RecordingRegionOverlayWindow.swift — force-sets crosshair outside selection
private func updateCursorFor(point: CGPoint) {
  if let handle = handleAt(point: point) {
    cursorFor(handle: handle).set()
    return
  }
  let localRect = localHighlightRect()
  if localRect.contains(point) {
    NSCursor.openHand.set()
  } else {
    NSCursor.crosshair.set()
  }
}
```

```swift
// AllInOneCaptureCoordinator.swift — HUDs are separate windows
private func installHUDs(using state: AllInOneCaptureSessionState) {
  let modeWindow = CaptureFloatingHUDWindow()
  modeWindow.setContent(AnyView(AllInOneCaptureToolbarView(session: state)))
  let actionWindow = CaptureFloatingHUDWindow()
  actionWindow.setContent(AnyView(AllInOneActionToolbarView(session: state)))
  modeHUD = modeWindow
  actionHUD = actionWindow
  positionHUDs()
}
```

Repo conventions:

- Swift 5.9, two-space indent, 120-column max (`.swiftformat`).
- Conventional commits (`fix: …`, `test: …`).
- New files under `Notinhas/` / `NotinhasTests/` are picked up by
  `PBXFileSystemSynchronizedRootGroup` — drop them in the matching folder; do
  not hand-edit `project.pbxproj` unless sync fails.
- Match FloatingToolbar naming: `CaptureFloating*` for shared capture HUD infra.

Vocabulary (from root `CONTEXT.md` after this round’s grill): prefer **barra
flutuante de captura (HUD)** for All-In-One’s separate panels; prefer **chrome
inline de captura** for Capture Markup’s in-panel controls. Do not call them the
same thing in comments.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Services/Capture/FloatingToolbar Notinhas/Features/Capture/AllInOne NotinhasTests/Services/Capture NotinhasTests/Features/Capture` | exit 0 |
| Focused tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingCursorExclusionTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` | exit 0, all listed tests pass |
| Changed-surface plan | `./scripts/verify-local.sh --base HEAD --plan-only` after edits (optional) | writes under `build/verification/` |

## Suggested executor toolkit

- Project skill `.agents/skills/testing-xctest/SKILL.md` when adding XCTest.
- Global `macos-app-engineering` + `.agents/overlays/macos-app-engineering.md` if
  unsure about nonactivating panel cursor ownership — but do **not** expand scope.
- Do **not** rewrite Capture Markup hosting to use `CaptureFloatingHUDWindow`.

## Scope

**In scope** (the only files you should create or modify):

- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingCursorExclusion.swift` (create)
- `NotinhasTests/Services/Capture/CaptureFloatingCursorExclusionTests.swift` (create)
- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift`
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch, even though they look related):

- `InlineAreaAnnotateWindow.swift` / Capture Markup chrome, materials, placement
- `CaptureFloatingToolbarPlacement.swift` / clamp extraction (plan 060)
- `RecordingRegionOverlayWindow.updateCursorFor` / `resetCursorRects` behavior
  for recording sessions
- `AreaSelectionController` / initial-drag cursor timer (manually verify; if still
  broken after this plan, STOP and report — do not invent a second fix here)
- Unifying button sizes, HUD materials, or hosting models between Markup and AIO
- Making `CaptureFloatingHUDWindow.canBecomeKey` return `true`

## Git workflow

- Branch: `advisor/059-all-in-one-hud-cursor-exclusion` (or worktree branch from
  `plan-execute-review`)
- Commit style examples from this repo: `fix: …`, `test: …`
- Do NOT push or open a PR unless the operator instructed it (orchestrator may
  integrate per `plan-execute-review`)

## Steps

### Step 1: Add pure exclusion helper + tests

Create `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingCursorExclusion.swift`:

```swift
import CoreGraphics

enum CaptureFloatingCursorExclusion {
  /// Returns true when `point` (AppKit screen coordinates) lies inside any HUD frame.
  static func contains(_ point: CGPoint, in frames: [CGRect]) -> Bool {
    frames.contains { $0.contains(point) }
  }
}
```

Create `NotinhasTests/Services/Capture/CaptureFloatingCursorExclusionTests.swift`
modeled after `CaptureFloatingToolbarPlacementTests.swift`:

- Point inside one frame → `true`
- Point outside all frames → `false`
- Empty frames → `false`
- Point on shared edge of adjacent frames (use `CGRect.contains` semantics; assert
  explicitly so future changes are intentional)

**Verify**:
`./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingCursorExclusionTests`
→ exit 0, all new tests pass.

### Step 2: Wire exclusion into the refinement cursor timer

In `AllInOneSelectionRefinementController`:

1. Add a provider the coordinator can set:

```swift
/// Screen-space frames of floating HUDs that must keep the arrow cursor.
var cursorExclusionFrames: () -> [CGRect] = { [] }
```

2. At the start of `handleCursorTrackingTick()`, after the empty-overlays guard
   and **before** the gesture-in-progress / overlay lookup paths that call
   `refreshCursor()`, if
   `CaptureFloatingCursorExclusion.contains(NSEvent.mouseLocation, in: cursorExclusionFrames())`
   then `NSCursor.arrow.set()` and `return`.

Also apply the same exclusion check on the gesture-in-progress early path: if the
pointer is over a HUD frame, set arrow and return instead of
`owner.refreshCursor()`. (HUD overlap during a resize is rare; still prefer arrow
over forced crosshair on chrome.)

Do **not** change Escape monitors, key-ownership transfer logic beyond the early
return, snapping, or overlay presentation.

**Verify**: `swiftformat` on touched paths → exit 0; build/test command in Step 3.

### Step 3: Coordinator supplies live HUD frames

In `AllInOneCaptureCoordinator.beginRefinement(with:)`, after assigning
`refinementController = controller` (and before or right after `controller.present()`),
set:

```swift
controller.cursorExclusionFrames = { [weak self] in
  guard let self else { return [] }
  var frames: [CGRect] = []
  if let modeHUD, modeHUD.isVisible {
    frames.append(modeHUD.frame)
  }
  if let actionHUD, actionHUD.isVisible {
    frames.append(actionHUD.frame)
  }
  return frames
}
```

Use whatever visibility check already matches AppKit usage in this codebase
(`isVisible` is fine on `NSWindow`). Clear the provider in teardown paths by
tearing down the controller (existing `tearDown` already nils the controller —
no need for a separate clear if the controller is discarded).

**Verify**:
`./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingCursorExclusionTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests`
→ exit 0.

### Step 4: Manual smoke (required for done criteria)

With Screen Recording granted, run the app (`./scripts/build_and_run.sh` or Xcode),
start **All-In-One**, complete/refine a selection so mode + dimensions HUDs are
visible, and hover each HUD button:

- Cursor must be the **standard arrow** (not crosshair) over HUD chrome.
- Buttons must still activate modes / edit W×H / toggle aspect lock.
- Moving off the HUD onto the dimmed overlay must restore crosshair / openHand /
  resize cursors as before.
- Capture Markup cursor behavior must remain unchanged (spot-check only).

If the bug still reproduces **only** during the first-drag `AreaSelectionController`
phase (before refinement starts), STOP and report — do not expand into
`AreaSelectionWindow` in this plan.

**Verify**: manual checklist above; note result in the commit message body or
PR notes when integrating.

## Test plan

- New file `CaptureFloatingCursorExclusionTests` covering contains / outside /
  empty frames (Step 1).
- Pattern: `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift`.
- Keep existing `AllInOneCaptureCoordinatorTests` green (no flaky UI required).
- Manual gate: All-In-One refinement HUD hover cursor (Step 4).

## Done criteria

- [ ] `CaptureFloatingCursorExclusion.contains` exists and is used by
      `AllInOneSelectionRefinementController.handleCursorTrackingTick`
- [ ] `./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingCursorExclusionTests -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` exits 0
- [ ] Manual All-In-One refinement: arrow over HUDs, selection cursors elsewhere
- [ ] No files outside the in-scope list are modified (`git status` / diff)
- [ ] `plans/README.md` status row for 059 updated

## STOP conditions

Stop and report back (do not improvise) if:

- Drift check shows in-scope files diverged from the "Current state" excerpts.
- The bug only reproduces during initial `AreaSelectionController` drag and not
  during refinement (needs a separate plan).
- Fix seems to require `canBecomeKey = true` on HUDs, or changes to
  `RecordingRegionOverlayWindow` shared with Recording start flow.
- Any step’s verification fails twice after a reasonable fix attempt.
- Scope pressure to “also unify Markup chrome / materials / button sizes”.

## Maintenance notes

- Any new All-In-One (or other) floating HUD shown during refinement must be
  included in `cursorExclusionFrames` or the crosshair will return over that chrome.
- Reviewers: confirm the early return does not break Escape / keyboard owner
  while hovering HUDs (Escape should still cancel via existing monitors).
- Deferred: shared screen-edge clamp helper (plan 060); Capture Markup hosting
  remains separate by design.
