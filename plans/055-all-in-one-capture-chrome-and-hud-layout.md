# Plan 055: Polish All-In-One selection chrome and side-by-side HUD layout

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 8ae2567c..HEAD -- \
>   Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift \
>   Notinhas/Features/Capture/AllInOne \
>   Notinhas/Services/Capture/FloatingToolbar \
>   NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift \
>   NotinhasTests/Features/Capture`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: direction
- **Planned at**: commit `8ae2567c`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — selection chrome and HUD placement must land together for a coherent All-In-One session.
- **Reviewer required**: yes — visual/layout correctness across selection, dual HUD windows, Reduce Transparency, and shared recording overlay API.
- **Rationale**: Scope is bounded, but it touches a shared `RecordingRegionOverlayWindow` draw path and dual floating panels; layout edge cases need a careful implementer, not a fast-lane patch.
- **Escalate when**: Fixing height/placement requires rewriting `CaptureFloatingHUDWindow` host material, changing recording-start `hideBorder()` semantics, or touching `AreaSelectionWindow` initial-drag chrome.

## Why this matters

All-In-One refinement currently draws a continuous white selection stroke plus L-shaped
handles, and hosts dimensions in a second floating HUD that sits below the selection
while the mode strip sits above it. The dimensions HUD also stacks material on material,
keeps a trailing divider with nothing after it, and nests a second “card” around W×H —
visually noisier than the mode strip. This plan removes only the continuous white stroke
(keeping handles), restyles the dimensions bar to match the mode strip’s single shell, and
places the dimensions HUD always to the right of the mode strip with a fixed 16pt gap and
matching height.

## Current state

Relevant files:

- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift` —
  draws dim fill, continuous white border, and resize handles; used by recording and by
  All-In-One refinement.
- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift` —
  creates `RecordingRegionOverlayWindow` instances for refinement (lines ~125–131).
- `Notinhas/Features/Capture/AllInOne/AllInOneDimensionsBarView.swift` —
  W×H fields + aspect lock; applies its own `.captureFloatingToolbarMaterial()` and a
  nested field-group background.
- `Notinhas/Features/Capture/AllInOne/AllInOneActionToolbarView.swift` —
  wraps dimensions again with padding + material + an orphan trailing divider.
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureToolbarView.swift` —
  mode strip exemplar: single material shell, no nested cards (match this).
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift` —
  owns `modeHUD` / `actionHUD` and currently stacks them via `modeToolbarAnchor`.
- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingToolbarPlacement.swift` —
  pure placement for a single toolbar size under/near an anchor.
- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingHUDWindow.swift` —
  borderless HUD host; `show(anchorRect:)` always re-runs single-toolbar placement.
- `Notinhas/Features/Recording/Components/RecordingToolbarStyles.swift` —
  `ToolbarConstants` (padding 6, button height via mode buttons = 46, corner radius 14).
- `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift` —
  pure geometry tests to extend for paired placement.

Load-bearing excerpts as of `8ae2567c`:

```swift
// RecordingRegionOverlayWindow.swift — constants + draw gate
private let borderColor = NSColor.white
private let borderWidth: CGFloat = 1.5
// ...
if showBorder {
  let borderPath = NSBezierPath(rect: clampedRect)
  borderPath.lineWidth = borderWidth
  borderColor.setStroke()
  borderPath.stroke()
  drawRecordingResizeHandles(for: clampedRect)
}
```

```swift
// AllInOneActionToolbarView.swift — double shell + orphan divider
HStack(spacing: ToolbarConstants.itemSpacing) {
  if session.selectedMode.showsDimensionsBar, let rect = session.currentRect {
    AllInOneDimensionsBarView(rect: rect) { updated in
      session.updateRect(updated)
    }
    CaptureFloatingToolbarDivider() // nothing after this
  }
}
.padding(.horizontal, ToolbarConstants.horizontalPadding)
.padding(.vertical, ToolbarConstants.verticalPadding)
.captureFloatingToolbarMaterial()
```

```swift
// AllInOneDimensionsBarView.swift — nested card + second material
HStack(spacing: 6) { /* width × height fields */ }
  .padding(.horizontal, 8)
  .padding(.vertical, 4)
  .background(
    RoundedRectangle(cornerRadius: ToolbarConstants.buttonCornerRadius)
      .fill(Color.primary.opacity(0.06))
  )
// root also calls .captureFloatingToolbarMaterial()
```

```swift
// AllInOneCaptureCoordinator.swift — vertical stack of HUDs
actionHUD.show(anchorRect: anchorRect)
let modeAnchor = modeToolbarAnchor(for: anchorRect, actionToolbarSize: actionHUD.frame.size)
modeHUD.show(anchorRect: modeAnchor)
// modeToolbarAnchor places mode ABOVE selection using action height + gap + 6
```

```swift
// AllInOneCaptureMode.swift
var showsDimensionsBar: Bool { preservesSelectionRect }
// false for .fullscreen and .window
```

Product / design constraints to honor:

- AGENTS.md product intent: speed and precise visual reference for the capture → annotate
  handoff; do not expand unrelated recording/cloud features.
- Reuse `ToolbarConstants` and `.captureFloatingToolbarMaterial()`; respect Reduce
  Transparency (already handled inside the material modifier).
- UI on MainActor; keep placement math pure/`nonisolated`-friendly like
  `CaptureFloatingToolbarPlacement`.

### Settled product decisions (do not reopen)

1. Remove continuous white border **only** for All-In-One refinement overlays. Leave
   `AreaSelectionWindow` initial-drag border and recording’s default bordered chrome alone.
2. Keep L-corner + edge handles exactly as drawn today.
3. Dimensions HUD stays a **separate** window; one material shell; no nested W×H card;
   no orphan divider; keep divider only between W×H group and lock.
4. Prefer the pair **below** the selection using existing vertical placement rules.
5. Dimensions HUD height matches the mode strip height; content vertically centered.
6. Always: mode (leading) | **16pt** | dimensions (trailing). **Never** invert order.
   **Never** stack vertically.
7. Horizontal overflow: treat the pair as one bounding box, center on selection `midX`,
   clamp as a unit (`screenEdgeInset = 10`). If pair is wider than the screen, pin the
   pair’s leading edge; dimensions may clip on the trailing side.
8. When dimensions are not shown (`.fullscreen` / `.window`, or no `currentRect`): do
   **not** show an empty action HUD; mode strip alone, existing single-toolbar placement.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Drift check | `git diff --stat 8ae2567c..HEAD -- Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift Notinhas/Features/Capture/AllInOne Notinhas/Services/Capture/FloatingToolbar NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift NotinhasTests/Features/Capture` | empty, or only explainable post-plan edits |
| Format | `swiftformat Notinhas/Features/Capture/AllInOne Notinhas/Services/Capture/FloatingToolbar Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift` | exit 0 |
| Placement + All-In-One unit tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests -only-testing:NotinhasTests/AllInOneCaptureModeTests` | all pass |
| Broader capture tests (if coordinator helpers touched) | `./scripts/run-tests.sh -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests` | all pass |
| Build/run for manual UI | `./scripts/build_and_run.sh --no-video-module` | app launches |

## Suggested executor toolkit

- `.agents/skills/capture-annotate-export/SKILL.md` — All-In-One sits in the capture
  handoff loop; keep scope on capture chrome, not annotate/export.
- Global `apple-design` + `.agents/overlays/apple-design.md` — materials, spacing,
  Reduce Transparency.
- Global `macos-app-engineering` — floating panels / overlays.
- Global `swift-conventions` — naming, `// MARK:`, two-space indent via SwiftFormat.
- `.agents/skills/testing-xctest/SKILL.md` — extend pure placement tests.

## Scope

**In scope** (the only files you should modify / create):

- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneDimensionsBarView.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneActionToolbarView.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift`
- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingToolbarPlacement.swift`
- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingHUDWindow.swift`
  (only if needed for absolute `show(at:)` / `orderOut` helpers — keep changes minimal)
- `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift`
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch):

- `Notinhas/Services/Capture/AreaSelectionWindow.swift` — initial-drag white border stays.
- `Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift` — different capture path.
- Recording start/stop flows beyond preserving existing `hideBorder()` / `showBorder()`
  behavior for the continuous stroke + handles pair when chrome is hidden for video.
- Mode strip button visuals in `AllInOneCaptureToolbarView` (except sharing a height
  token if you extract one — do not redesign mode buttons).
- Localization copy, preferences, ImgBB, Notinhas annotate/export.
- Docs under `docs/` unless a single sentence in `docs/CAPTURE.md` is already wrong about
  HUD stacking; prefer no doc churn.

## Git workflow

- Branch: `implement/055-all-in-one-capture-chrome-and-hud-layout` (match recent
  `implement/0NN-*` style).
- Commits: Conventional Commits, e.g. `fix(capture): side-by-side All-In-One HUD layout`
  or `feat(capture): drop All-In-One selection outline stroke`. Recent style from log:
  `feat(preferences): …`, `fix(notinhas): …`, `docs(plans): …`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 0: Drift check

Run the drift-check command in the executor instructions. Confirm excerpts still match.

**Verify**: drift command exits 0; if diff is non-empty, STOP and report.

### Step 1: Split continuous border from handles in the shared overlay

In `RecordingRegionOverlayView` / `RecordingRegionOverlayWindow`:

1. Add a flag such as `drawsContinuousBorder: Bool = true` (default **true** so
   recording keeps today’s stroke).
2. Expose a setter on the window, e.g. `setDrawsContinuousBorder(_:)`, mirroring
   `hideBorder()` / `showBorder()` style.
3. In `draw(_:)` when `showBorder` is true:
   - If `drawsContinuousBorder`, stroke the white `NSBezierPath` as today.
   - **Always** still call `drawRecordingResizeHandles(for:)` when `showBorder` is true.
4. In `drawNewSelection()` (in-overlay reselect drag): if `drawsContinuousBorder` is
   false, skip the temporary white stroke; leave the transient size chip as-is unless it
   becomes visually broken without a stroke (if so, keep the chip).
5. Do **not** change `hideBorder()` semantics: when `showBorder == false`, neither stroke
   nor handles draw (recording-in-progress must stay clean).

In `AllInOneSelectionRefinementController.makeRegionOverlay(for:)`:

```swift
overlay.setDrawsContinuousBorder(false) // or equivalent
```

**Verify**:
`rg -n "drawsContinuousBorder|setDrawsContinuousBorder" Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift`
→ both files reference the new API; All-In-One sets it false; default remains true.

### Step 2: Restyle the dimensions bar to match the mode strip

Target visual structure (mirror `AllInOneCaptureToolbarView`):

```swift
HStack(spacing: ToolbarConstants.itemSpacing) {
  // width field, "×", height field — NO nested RoundedRectangle background
  CaptureFloatingToolbarDivider()
  CaptureFloatingToolbarIconButton(/* lock */)
}
.padding(.horizontal, ToolbarConstants.horizontalPadding)
.padding(.vertical, ToolbarConstants.verticalPadding)
.frame(minHeight: /* mode button content height 46 */) // see height note
.captureFloatingToolbarMaterial()
```

Concrete edits:

1. `AllInOneDimensionsBarView`: remove the nested `.background(RoundedRectangle…)` on
   `dimensionFieldGroup`. Keep plain fields + `×` + divider + lock.
2. Keep **one** `.captureFloatingToolbarMaterial()` on the dimensions root (same as mode
   strip).
3. `AllInOneActionToolbarView`: stop applying a second material / outer padding / orphan
   trailing divider. Prefer a thin host that only embeds `AllInOneDimensionsBarView` when
   `showsDimensionsBar && currentRect != nil`, otherwise `EmptyView`.
4. **Same height as mode strip**: mode buttons use `.frame(width: 54, height: 46)` plus
   shared vertical padding 6 → outer height ≈ 58. Give the dimensions content
   `minHeight: 46` (or a shared private constant / `ToolbarConstants` addition such as
   `modeButtonHeight = 46` if you need one token) so fitting height matches the mode HUD.
   Vertically center the HStack content.
5. Do not change lock behavior, field parsing, or aspect-ratio preference keys.

**Verify**:
`rg -n "captureFloatingToolbarMaterial" Notinhas/Features/Capture/AllInOne/AllInOneDimensionsBarView.swift Notinhas/Features/Capture/AllInOne/AllInOneActionToolbarView.swift`
→ material appears once on the dimensions content path, not twice.
`rg -n "RoundedRectangle\\(cornerRadius: ToolbarConstants.buttonCornerRadius\\)" Notinhas/Features/Capture/AllInOne/AllInOneDimensionsBarView.swift`
→ no nested field-group fill remains (lock button hover fill inside
`CaptureFloatingToolbarIconButton` is fine and lives in chrome, not this file).

### Step 3: Pure paired-placement API (16pt gap, fixed order)

Extend `CaptureFloatingToolbarPlacement` (same file; keep existing
`frameOrigin(toolbarSize:anchorRect:screenFrame:)` unchanged for single-toolbar callers):

Add something equivalent to:

```swift
static let interToolbarGap: CGFloat = 16

struct PairedOrigins: Equatable {
  let leading: CGPoint
  let trailing: CGPoint?
}

static func pairedFrameOrigins(
  leadingSize: CGSize,
  trailingSize: CGSize?, // nil → leading only, uses existing frameOrigin
  anchorRect: CGRect,
  screenFrame: CGRect,
  gap: CGFloat = interToolbarGap
) -> PairedOrigins
```

Algorithm (must match settled decisions):

1. If `trailingSize == nil`, return `(frameOrigin(leadingSize…), nil)`.
2. Let `pairHeight = max(leadingSize.height, trailingSize.height)`.
3. Let `pairWidth = leadingSize.width + gap + trailingSize.width`.
4. Let `pairSize = CGSize(width: pairWidth, height: pairHeight)`.
5. Let `pairOrigin = frameOrigin(toolbarSize: pairSize, anchorRect:, screenFrame:)` —
   reuses below-selection preference + clamping.
6. `leading = pairOrigin`.
7. `trailing = CGPoint(x: pairOrigin.x + leadingSize.width + gap, y: pairOrigin.y)` —
   **same Y** (tops aligned). Never place trailing left of leading. Never stack.

Optional hardening: if callers pass unequal heights, still align on `pairOrigin.y` and
expect Step 2 to make heights equal; do not vertically center one bar relative to the
other in a way that breaks “same height” (prefer forcing equal content heights upstream).

**Verify**: add tests in `CaptureFloatingToolbarPlacementTests` (Step 5) before relying on
coordinator wiring — write tests first if preferred, but they must exist before Done.

### Step 4: Wire coordinator HUDs side-by-side

Rewrite `AllInOneCaptureCoordinator.positionHUDs()` roughly as:

1. `modeHUD.refreshContentSize()` always when present.
2. Determine `showsDimensions = session.selectedMode.showsDimensionsBar && session.currentRect != nil`.
3. If `!showsDimensions`: `actionHUD?.orderOut(nil)` (or equivalent hide); position
   `modeHUD` with existing `show(anchorRect:)` / single placement. Remove use of
   `modeToolbarAnchor`.
4. If `showsDimensions`: refresh action content size; compute
   `pairedFrameOrigins(leading: modeSize, trailing: actionSize, …)` using the selection
   anchor (or `defaultAnchorRect()`); set both windows’ origins and `orderFront`; never
   call the old stacked `modeToolbarAnchor`.
5. Delete `modeToolbarAnchor(for:actionToolbarSize:)` once unused.
6. If `CaptureFloatingHUDWindow.show(anchorRect:)` always re-centers a single toolbar,
   add a minimal `show(at origin: CGPoint)` (or `position(at:)`) that sets the frame
   origin and orders front **without** recomputing single-toolbar placement — use that
   for the paired path.

Ensure `showAboveCaptureOverlay()` during initial selection still raises z-order for the
mode HUD; action HUD stays hidden until a rect exists and the mode preserves selection.

**Verify**:
`rg -n "modeToolbarAnchor" Notinhas/Features/Capture/AllInOne`
→ no matches.
`rg -n "interToolbarGap|pairedFrameOrigins" Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift Notinhas/Services/Capture/FloatingToolbar`
→ coordinator uses paired placement with 16pt gap.

### Step 5: Unit tests for paired placement

Extend `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift`
(model after existing tests in that file). Required cases:

1. **Happy path below selection**: with room below, pair origin Y equals
   `selection.minY - pairHeight - outsideSelectionGap`; leading X centers the **pair** on
   `selection.midX`; trailing X equals `leading.x + leadingWidth + 16`.
2. **Trailing nil**: matches existing single `frameOrigin` for the leading size.
3. **Horizontal clamp**: selection near the trailing screen edge — pair shifts left so
   leading stays at/after `screen.minX + screenEdgeInset`; trailing remains to the right
   of leading by exactly `leadingWidth + 16` (order preserved).
4. **Oversized pair**: pair wider than screen — leading X pinned to
   `screen.minX + screenEdgeInset`; trailing still to the right (may extend past screen);
   never inverted.

Do not add UI/snapshot tests for SwiftUI chrome.

**Verify**:
`./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests`
→ all pass, including the new cases.

### Step 6: Format + focused regression

Run SwiftFormat on touched Swift paths, then:

```bash
./scripts/run-tests.sh \
  -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests \
  -only-testing:NotinhasTests/AllInOneCaptureModeTests \
  -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests
```

**Verify**: exit 0; `git status` shows only in-scope paths (+ plan README status).

### Step 7: Manual visual gate (required)

With Screen Recording permission, run `./scripts/build_and_run.sh --no-video-module`,
trigger All-In-One, and confirm:

- [ ] Refined selection shows **handles only** (no continuous white outline).
- [ ] Mode strip and dimensions HUD sit on one horizontal band; dimensions to the right;
      ~16pt gap; equal height; single material each (no nested W×H card; no orphan divider).
- [ ] Pair prefers below the selection; moving the selection near screen edges clamps the
      **pair** without swapping order or stacking.
- [ ] Switching to Fullscreen/Window hides the dimensions HUD; mode strip remains alone.
- [ ] Aspect lock + editing W×H still update the selection rect.

If Video module is available locally, spot-check that recording region overlay still shows
the white stroke + handles before record starts (default `drawsContinuousBorder == true`).

**Verify**: checklist above; note any failure as BLOCKED in `plans/README.md` rather than
shipping a partial layout.

## Test plan

- **New / extended**: `CaptureFloatingToolbarPlacementTests` — paired origins happy path,
  trailing-nil, trailing-edge clamp, oversized pair (see Step 5).
- **Pattern**: existing tests in the same file (`testCaptureFloatingToolbarPlacement_usesOutsideGapWhenBelowSelectionFits`).
- **Existing keep-green**: `AllInOneCaptureModeTests`, `AllInOneCaptureCoordinatorTests`.
- **Not required**: SwiftUI view tests for material; overlay bitmap tests for missing
  stroke (manual gate covers that).

Verification command:

```bash
./scripts/run-tests.sh \
  -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests \
  -only-testing:NotinhasTests/AllInOneCaptureModeTests \
  -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests
```

→ all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] Drift check against `8ae2567c` reviewed; in-scope excerpts reconciled if needed.
- [ ] All-In-One refinement sets continuous border off; handles still draw when chrome is on.
- [ ] Recording default still draws continuous border when `showBorder == true` (flag default
      true; `hideBorder()` still hides stroke + handles).
- [ ] Dimensions HUD: single material; no nested W×H card; no orphan divider; lock divider kept.
- [ ] `modeToolbarAnchor` removed; paired placement uses 16pt gap; order never inverted/stacked.
- [ ] Action HUD hidden when dimensions are not shown.
- [ ] `./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests`
      (and All-In-One mode/coordinator selectors above) exit 0 with new paired tests.
- [ ] `swiftformat` clean on touched Swift paths.
- [ ] No files outside the in-scope list are modified (`git status` / `git diff --name-only`).
- [ ] `plans/README.md` status row for 055 updated.
- [ ] Manual checklist in Step 7 completed (or explicitly BLOCKED with reason).

## STOP conditions

Stop and report back (do not improvise) if:

- In-scope excerpts drifted and the new structure is not an obvious rename of the same
  responsibilities.
- Making handles-without-stroke requires changing hit-testing geometry or cursor rects
  (should not — only drawing changes).
- Equal height cannot be achieved without redesigning mode buttons or breaking
  `CaptureFloatingToolbarIconButton` sizing — report instead of inventing a third chrome
  system.
- Paired placement appears to require inverting order or stacking to “fit” — that
  contradicts settled decisions; implement clamp/pin only.
- Fix seems to require editing `AreaSelectionWindow` or Inline Area Annotate chrome.
- A verification command fails twice after a reasonable fix attempt.
- You discover `actionHUD` empty `EmptyView` still yields a non-trivial fitting size that
  cannot be ordered out — stop and report rather than drawing an invisible pill.

## Maintenance notes

- Future All-In-One HUD controls (extra buttons beside dimensions) should extend the
  **trailing** HUD content or widen `trailingSize` — do not reintroduce vertical stacking
  relative to the mode strip.
- If recording gains a “handles only” pre-roll look, reuse `drawsContinuousBorder`; do not
  fork a second overlay class.
- Reviewers should scrutinize: (1) recording `hideBorder()` still clears handles, (2) 16pt
  gap measured between window frames, (3) z-order during initial area drag, (4) Reduce
  Transparency still readable on both pills.
- Deferred: restyling the initial-drag white border in `AreaSelectionWindow`; unifying
  Inline Area Annotate handle chrome; docs screenshots for All-In-One.
