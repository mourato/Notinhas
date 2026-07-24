# Plan 062: Unify selection behavior and All-In-One HUD ownership

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and record the result before moving on. If a STOP
> condition occurs, stop and report it; do not replace the decision with an
> assumption. This plan is intentionally split into two atomic implementation
> commits, but both commits must be integrated and reviewed together.
>
> **Drift check (run first)**:
> `git diff --stat 0169e0fd..HEAD -- \
>   Notinhas/Services/Capture \
>   Notinhas/Features/Annotate \
>   Notinhas/Features/Recording \
>   Notinhas/Features/Capture/AllInOne \
>   NotinhasTests/Services/Capture \
>   NotinhasTests/Features/Annotate \
>   NotinhasTests/Features/Capture \
>   plans/059-all-in-one-hud-cursor-exclusion.md \
>   plans/060-capture-floating-screen-clamp.md \
>   plans/061-shared-selection-chrome.md`
>
> The plan was written at `0169e0fd20b7a63e7e47da022f0de2c50ccb1e4c`.
> `CONTEXT.md` may contain the already-recorded domain vocabulary change; do
> not discard or fold unrelated documentation work into the implementation.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 059, 060, and 061 integrated; no historical plan is reopened
- **Category**: behavior / architecture
- **Planned at**: commit `0169e0fd`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — selection contract and cursor/layer ownership cross the same capture hosts
- **Reviewer required**: yes — thermo-nuclear review after both implementation commits
- **Implementation commits**:
  1. `refactor: share capture selection behavior and chrome`
  2. `fix: unify All-In-One floating HUD ownership`
- **Integration**: use the repository's `plan-execute-review` loop; after the
  executor commits, merge/integrate, run the review, fix every finding, then
  run the final gates.

## Outcome

Make the already-selected area feel like the same product interaction in
Capture Markup, All-In-One refinement, and Recording pre-record selection,
while preserving each host's session and coordinate model. The shared contract
includes:

- selection creation preview and confirmed-area adjustment;
- L-handle appearance, adaptive geometry, hit tests, and resize cursors;
- the confirmed-area minimum size;
- visual contrast of the chrome, using host-provided image/luminance context;
- one snapping engine and policy, with candidates supplied by each host.

Make the two All-In-One floating bars behave like the other capture bars:
both have the same layer policy, deterministic hit testing, arrow cursor over
controls, first-click reliability, and no focus theft. A single AIO cursor
arbiter must own the decision instead of several 60 Hz timers overwriting one
another.

## Decisions already confirmed

These are product decisions, not implementation suggestions:

1. Share the visual and interaction contract, but keep the session hosts
   separate. AIO may retain aspect lock; Markup does not acquire it.
2. During initial AIO area creation, keep crosshair + selection-rectangle
   behavior. Handles appear when the area is confirmed and enters refinement.
   Markup and Recording keep their own session phases; their confirmed-area
   chrome consumes the shared contract.
3. Snapping sensitivity to image color/luminance is separate from visual
   contrast of handles and borders. Contrast is shared as a policy; luma/image
   acquisition remains host-specific.
4. Snapping is shared. Screen-boundary candidates are common; visual, color,
   or semantic candidates are optional and supplied only where a host already
   has the relevant source. Do not add new TCC/AX acquisition just to force
   parity.
5. A confirmed selection uses a common 50 pt minimum in AIO, Markup, and
   Recording. Initial creation keeps its separate small threshold (>5 pt where
   that host currently accepts it).
6. Handle geometry is adaptive for compact rectangles. Corners remain usable;
   edge handles are omitted when there is not enough room. Corner hit targets
   take priority and must not create ambiguous overlap.
7. Recording parity means the pre-record selection only. While recording,
   selection is disabled and handles are hidden.
8. AIO HUDs use `.popUpMenu` as the normal level. When they must sit above the
   initial `.screenSaver` selection overlay, both bars transition together and
   return together. The bars accept the first click, remain nonactivating, and
   preserve the captured app's focus.
9. AIO/Recording remain the visual source of truth; the shared layer is a pure
   model/geometry/policy layer with AppKit and SwiftUI host renderers.
10. Automated tests cover pure geometry/policy and lifecycle invariants;
    manual validation covers WindowServer, TCC, real cursors, two displays,
    and varied backgrounds.

## Current state and why 061 is insufficient

The following facts are the fixed point for this plan:

- `CaptureSelectionGeometry.swift:26–75` already owns normalization and
  resizing, but its callers do not use one common confirmed-area minimum.
- `CaptureSelectionChromeMetrics.swift:8–15` and
  `CaptureSelectionHandleGeometry.swift:150–end` provide fixed 20/24 pt bars,
  3 pt thickness, and 10 pt hit sizing. Compact selections can therefore
  overlap or render handles outside the usable area; the old Markup behavior
  was adaptive and suppressed edge bars when necessary.
- `InlineAreaAnnotateWindow.swift:265–275` only renders resize handles in the
  `.annotating` phase. Its selection phase updates the rect but has no shared
  creation-preview chrome; its resize path around `:547–574` still applies a
  Markup-local 24 pt minimum. It uses desktop-local, top-left coordinates.
- `RecordingRegionOverlayWindow.swift` uses the shared handle hit geometry but
  still owns resize arithmetic and a 50 pt minimum locally. It uses AppKit
  screen, bottom-left coordinates and supports cross-display/reselection.
- `CaptureSelectionSnapping.swift:14–45, 107–171` is pure and already has the
  right candidate/resolver shape, but it is wired primarily to AIO. AIO loads
  the preference values in `AllInOneSelectionRefinementController.swift` and
  is the only host currently using image/color-sensitive snapping.
- `AllInOneCaptureCoordinator.swift:127–165` starts the initial selection and
  raises only `modeHUD`; `:168–230` also starts a separate HUD cursor timer;
  `:254–282` positions/shows the bars without normalizing their level.
- `CaptureFloatingHUDWindow.swift:59–126` defaults to `.popUpMenu`, can neither
  become key nor currently accept the first mouse explicitly, and has its own
  tracking/cursor writes. `showAboveCaptureOverlay()` can set `.screenSaver`.
- `AreaSelectionWindow.swift` uses `.screenSaver` and has a 60 Hz pointer/key
  ownership timer. `AllInOneSelectionRefinementController.swift` has another
  60 Hz cursor timer. The coordinator adds a third exclusion writer. The
  resulting cursor decision can be overwritten after the pointer is over a HUD,
  and the two HUDs can occupy different levels depending on the path.

Do not “fix” these symptoms by merging the AppKit and SwiftUI hosts. The
problem is shared behavior and ownership, not identical session state.

## Scope

### In scope

- `Notinhas/Services/Capture/CaptureSelectionGeometry.swift`
- `Notinhas/Services/Capture/CaptureSelectionChromeMetrics.swift`
- `Notinhas/Services/Capture/CaptureSelectionHandleGeometry.swift`
- `Notinhas/Services/Capture/CaptureSelectionSnapping.swift`
- new pure helpers under `Notinhas/Services/Capture/`, preferably
  `CaptureSelectionChromeAppearance.swift` and
  `CaptureSelectionCursorPolicy.swift` (keep names coherent if the existing
  architecture suggests a better split)
- `Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift` and, only if
  needed for the phase/resize contract, `InlineAreaAnnotateSession.swift`
- `Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneSelectionRefinementController.swift`
- `Notinhas/Features/Capture/AllInOne/AllInOneCaptureCoordinator.swift`
- `Notinhas/Services/Capture/AreaSelectionWindow.swift`
- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingHUDWindow.swift`
- focused XCTest files under the corresponding Capture, Annotate, and
  All-In-One test directories
- the plan status/index in `plans/README.md`

### Out of scope

- merging `InlineAreaAnnotatePanel`, `RecordingRegionOverlayWindow`, or the AIO
  refinement overlay into one host;
- changing AIO aspect-lock semantics or adding aspect lock to Markup;
- forcing Accessibility, image capture, or Screen Recording/TCC acquisition
  into a host that does not already provide that candidate source;
- changing HUD materials, button sizes, bar heights, placement constants, or
  Markup's tool deck/property/action-rail visuals;
- changing the classic ⌘⇧4 commit-on-mouseup flow beyond the shared creation
  preview needed for the contract;
- active-recording selection behavior, annotation tools, export, clipboard,
  Notinhas session persistence, or unrelated plans 056–058.

## Step 1 — Characterize the contract before refactoring

Add or extend focused tests before changing host code. Lock these invariants:

- large rectangle (`200 × 120`) keeps the current AIO/Recording handle bar
  metrics and hit-test mapping;
- confirmed compact rectangles (`50 × 50`, then the smallest Markup case)
  produce adaptive corner bars, suppress unusable edge bars, and never allow a
  corner hit to lose to an edge hit;
- top-left and bottom-left coordinate adapters map the same logical handles;
- common confirmed resizing clamps at 50 pt while initial creation retains its
  separate >5 pt threshold;
- contrast policy responds to host-provided luma/background context and has a
  deterministic fallback; it does not read snapping sensitivity;
- the same snapping configuration/resolver result is obtained from equivalent
  candidates in each host coordinate space;
- a pure cursor policy returns arrow for HUD controls and a resize/crosshair
  cursor only when the pointer is outside the HUD exclusion region;
- both HUDs have one level state in initial-selection, saved-rect/refinement,
  and teardown transitions; `acceptsFirstMouse` is true and
  `canBecomeKey` remains false.

Suggested test files:

- `NotinhasTests/Services/Capture/CaptureSelectionChromeTests.swift`
- `NotinhasTests/Services/Capture/CaptureSelectionChromeAppearanceTests.swift`
- `NotinhasTests/Services/Capture/CaptureSelectionCursorPolicyTests.swift`
- `NotinhasTests/Services/Capture/CaptureSelectionSnappingTests.swift`
- `NotinhasTests/Features/Annotate/InlineAreaAnnotateSessionTests.swift`
- `NotinhasTests/Features/Capture/AllInOneCaptureCoordinatorTests.swift`
- `NotinhasTests/Services/Capture/CaptureFloatingHUDWindowTests.swift` (or the
  existing nearest HUD test file)

**Verify**:

```sh
./scripts/run-tests.sh \
  -only-testing:NotinhasTests/CaptureSelectionChromeTests \
  -only-testing:NotinhasTests/CaptureSelectionChromeAppearanceTests \
  -only-testing:NotinhasTests/CaptureSelectionCursorPolicyTests \
  -only-testing:NotinhasTests/CaptureSelectionSnappingTests
```

The new policy tests may initially be red if their production seams do not
exist; do not weaken the expectations to match the current bug.

## Step 2 — Implement the shared selection contract (commit 062A)

1. Make `CaptureSelectionChromeMetrics` and
   `CaptureSelectionHandleGeometry` the single pure source for adaptive L-bar
   drawing geometry, disjoint/prioritized hit geometry, and cursor-handle
   mapping. Preserve the large-rectangle numeric result. Make “edge handle is
   unavailable” explicit rather than returning a zero-size bar that still wins
   hit testing.
2. Add a pure appearance/contrast policy. It receives host-provided context
   (for example sampled luma or a known backdrop classification) and returns
   the chrome colors/stroke choice. Keep visual contrast independent from
   `CaptureSelectionSnappingConfiguration.colorSensitivity`; do not rename or
   reuse that preference as a contrast setting.
3. Generalize the existing pure snapping resolver into the shared contract.
   Keep its source priority and approach-side behavior deterministic. Expose a
   host adapter for coordinate transforms and candidate collection. Every host
   contributes screen-boundary candidates; AIO may continue contributing
   semantic/visual/color candidates, Markup contributes image/backdrop
   candidates only when it already has them, and Recording contributes the
   sources available before recording. Preserve AIO's aspect-lock ordering and
   add tests for it rather than silently changing it.
4. Refactor Markup and Recording resize paths to use
   `CaptureSelectionGeometry.resizedRect` plus the host coordinate adapter and
   common 50 pt confirmed minimum. Keep Markup's top-left desktop-local model,
   its selecting→annotating state machine, and its separate initial-creation
   threshold. Keep Recording's bottom-left cross-display behavior and hide or
   disable selection once recording begins.
5. Render the shared creation preview while a selection is being formed: the
   active crosshair remains host-owned, but the dragged rectangle must have a
   visible, contrast-safe preview. Do not show resize handles until the area is
   confirmed/refinement begins. In `.annotating`, Markup consumes the same L
   handles and hit/cursor contract as AIO/Recording.
6. Keep AppKit and SwiftUI renderers thin: they translate coordinate spaces and
   host context into the pure helpers; they must not fork metric constants or
   implement a second resize/snap algorithm.

**Verify**:

```sh
swiftformat \
  Notinhas/Services/Capture \
  Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift \
  Notinhas/Features/Annotate/InlineAreaAnnotateSession.swift \
  Notinhas/Features/Recording/Managers/RecordingRegionOverlayWindow.swift \
  Notinhas/Features/Capture/AllInOne \
  NotinhasTests/Services/Capture \
  NotinhasTests/Features/Annotate \
  NotinhasTests/Features/Capture

./scripts/run-tests.sh \
  -only-testing:NotinhasTests/CaptureSelectionChromeTests \
  -only-testing:NotinhasTests/CaptureSelectionChromeAppearanceTests \
  -only-testing:NotinhasTests/CaptureSelectionSnappingTests \
  -only-testing:NotinhasTests/InlineAreaAnnotateSessionTests
```

## Step 3 — Unify All-In-One HUD level, hit, and cursor ownership (commit 062B)

1. Add explicit HUD level state to `CaptureFloatingHUDWindow`. `.popUpMenu` is
   the normal level; the above-selection state is an explicit transition, not
   an incidental side effect of one `show` call. Make the coordinator apply the
   state to both `modeHUD` and `actionHUD` together, including the saved-rect
   path and the initial-selection path. Hidden HUDs must still be normalized
   before becoming visible. Teardown restores the normal level and removes all
   tracking/exclusion state.
2. Override `acceptsFirstMouse(for:)`/the equivalent window hook so a HUD
   control works on the first click while another app is active. Keep
   `canBecomeKey == false`, nonactivating behavior, and event routing intact.
   Do not make the HUD click-through.
3. Introduce one explicit AIO cursor arbiter/policy. It must classify the
   pointer as HUD, handle, inside-selection, or outside, and be the only AIO
   owner that commits the final cursor. HUD regions always resolve to arrow;
   selection handles resolve to the shared resize cursor; initial selection
   outside the HUD keeps crosshair behavior. The overlay may supply the
   non-HUD cursor candidate, but it must not overwrite the arbiter's HUD result.
4. Remove or subordinate the coordinator, initial-area, refinement, and HUD
   tracking timers so multiple 60 Hz writers no longer race. Keep pointer/key
   ownership and cross-display reconciliation, Escape cancellation, and
   selection event handling unchanged. Prefer one session-level update path
   with injected exclusion frames over adding more timers.
5. Add lifecycle tests for both HUDs and pure cursor-policy tests. If a
   WindowServer fact cannot be unit-tested, encode the invariant at the
   coordinator/window seam and leave the real-pointer check to the manual gate.

**Verify**:

```sh
./scripts/run-tests.sh \
  -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests \
  -only-testing:NotinhasTests/CaptureFloatingHUDWindowTests \
  -only-testing:NotinhasTests/AreaSelectionMultiMonitorReconciliationTests \
  -only-testing:NotinhasTests/CaptureSelectionCursorPolicyTests
```

## Step 4 — Integrated validation and manual matrix

Run the focused suite after both commits, then the changed-surface planner:

```sh
./scripts/run-tests.sh \
  -only-testing:NotinhasTests/CaptureSelectionChromeTests \
  -only-testing:NotinhasTests/CaptureSelectionChromeAppearanceTests \
  -only-testing:NotinhasTests/CaptureSelectionCursorPolicyTests \
  -only-testing:NotinhasTests/CaptureSelectionSnappingTests \
  -only-testing:NotinhasTests/InlineAreaAnnotateSessionTests \
  -only-testing:NotinhasTests/AllInOneCaptureCoordinatorTests \
  -only-testing:NotinhasTests/CaptureFloatingHUDWindowTests

./scripts/verify-local.sh --base 0169e0fd --plan-only --strict
```

Manual validation requires Screen Recording and Accessibility permissions where
the existing flows need them:

| Flow | Checks |
|---|---|
| AIO initial area | Crosshair creates a visible rectangle; no handles during drag; confirmed area enters refinement with shared handles; both HUDs stay coherent |
| AIO refinement | All eight usable handles, compact selection behavior, aspect lock, screen/image/semantic snapping where available |
| Markup | Creation preview, confirmed 50 pt minimum, adaptive handles, resize cursors, annotate/tools/export unchanged |
| Recording pre-record | Same confirmed-area chrome and snapping contract; cross-display resize/reselection remains correct |
| Recording active | Selection/handles are disabled/hidden |
| Backgrounds | Light/dark/high-contrast image transitions; chrome stays legible; changing color sensitivity changes snapping only |
| HUD hover/click | Arrow over both bars, first click works while another app is active, no focus theft, no click-through |
| Displays | HUD and selection overlay on each display; no stale exclusion frame or asymmetric level |

## STOP conditions

Stop and report if any of these occurs:

- the live code differs from the fixed-point excerpts in a way not explained by
  059–061, or another WIP touches the same files;
- implementing shared snapping requires inventing a new image capture,
  Accessibility, or TCC pipeline for Markup/Recording;
- a coordinate adapter cannot preserve the existing top-left/bottom-left or
  cross-display behavior;
- preserving AIO aspect lock would require changing the resolver's established
  order without a new product decision;
- the only way to pass cursor tests is to retain multiple independent cursor
  writers or to make a HUD key/activating;
- the common 50 pt confirmed minimum breaks an explicitly tested host behavior
  that the user decisions above did not permit changing;
- files outside the scope are required, or the same verification gate fails
  twice for an unexplained environment/tooling reason.

## Done criteria

- The shared selection contract is implemented by Markup, AIO refinement, and
  Recording pre-record without merging their hosts.
- Large and compact selection tests cover adaptive handles, hit priority,
  minimum sizes, coordinate spaces, contrast, and snapping.
- Both AIO HUDs transition as one layer state, accept first mouse, preserve app
  focus, and no longer compete with overlay timers for cursor ownership.
- Focused tests and `verify-local --strict` pass, or any environment-only gate
  is explicitly reported with its output.
- Manual matrix is recorded; Screen Recording/Accessibility/TCC limitations are
  not hidden.
- `plans/README.md` is updated only after the implementation/review loop with
  the resulting commit SHAs and any pending manual gate.
