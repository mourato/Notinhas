# Plan 060: Extract shared screen-edge origin clamp for capture chrome

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat 5c30ed4b..HEAD -- \
>   Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingToolbarPlacement.swift \
>   Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift \
>   NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.
>
> Prefer landing **after** plan 059 so All-In-One cursor behavior is stable
> before touching placement helpers. Code dependency is soft (different files);
> execution order is still 059 → 060.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/059-all-in-one-hud-cursor-exclusion.md (execution order; soft code dep)
- **Category**: tech-debt
- **Planned at**: commit `5c30ed4b`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: no — serialize after 059 to keep All-In-One review diffs small
- **Reviewer required**: no — pure helper extraction with existing placement tests
- **Rationale**: Moves an already-tested private clamp to a named shared API and
  documents why Capture Markup must **not** silently adopt different fallback
  semantics. No product UI change when placement results stay identical.
- **Escalate when**: Someone asks to merge `InlineAreaControlGeometry` prefer-above
  layout with `CaptureFloatingToolbarPlacement` prefer-below layout, or to change
  gaps/insets (`12`/`16` vs `10`/`20`/`24`).

## Why this matters

All-In-One floating HUDs already share `CaptureFloatingToolbarPlacement`, which
privately clamps toolbar origins so oversized chrome stays on-screen
(reversed `maximum < minimum` → keep leading edge at `minimum`). Capture Markup
uses a **different** clamp family (center-based, mid-screen fallback when the
range inverts) inside `InlineAreaControlGeometry`.

Product decision (**infra reuse, distinct looks**): share the **origin clamp
contract** used by floating HUD placement; do **not** unify placement preferences,
gaps, materials, or button sizes. This plan makes the floating-HUD clamp a
named, tested primitive so future capture HUDs reuse it without copying the
reversed-range edge case.

## Current state

Relevant files:

- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingToolbarPlacement.swift` —
  `frameOrigin` / `pairedFrameOrigins`; private `clampedOrigin`.
- `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift` —
  already covers oversized toolbar / edge clamp behavior.
- `Notinhas/Features/Annotate/InlineAreaAnnotateWindow.swift` —
  `InlineAreaControlGeometry.clampedControlCenterX` and private `clamped(_:min:max:)`
  with **different** inverted-range behavior (return mid / return value).

Load-bearing excerpts as of `5c30ed4b`:

```swift
// CaptureFloatingToolbarPlacement.swift
private static func clampedOrigin(_ origin: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
  guard maximum >= minimum else {
    // The toolbar cannot fit on this display. Keep its leading edge visible rather than
    // allowing a reversed clamp range to produce an unpredictable origin.
    return minimum
  }
  return max(minimum, min(origin, maximum))
}
```

```swift
// InlineAreaAnnotateWindow.swift — DO NOT silently replace with origin clamp
private static func clampedControlCenterX(...) -> CGFloat {
  let minX = width / 2 + controlInsets.controlLeadingPadding
  let maxX = containerSize.width - width / 2 - controlInsets.controlTrailingPadding
  guard minX <= maxX else {
    return containerSize.width / 2  // mid fallback — intentional for Markup
  }
  return clamped(preferredX, min: minX, max: maxX)
}

private static func clamped(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
  guard minValue <= maxValue else { return value }
  return min(max(value, minValue), maxValue)
}
```

Repo conventions: same as plan 059 (SwiftFormat, Conventional commits, synced
Xcode groups). Vocabulary: **barra flutuante de captura (HUD)** vs **chrome
inline de captura** — keep placement algorithms separate.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Services/Capture/FloatingToolbar NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift` | exit 0 |
| Placement tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests` | exit 0, all pass |
| Optional new helper tests | include `-only-testing:NotinhasTests/CaptureFloatingScreenClampTests` if you add that file | exit 0 |

## Suggested executor toolkit

- `.agents/skills/testing-xctest/SKILL.md` for pure geometry tests.
- Do **not** open Capture Markup layout for “consistency” changes.

## Scope

**In scope**:

- `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingToolbarPlacement.swift`
- Optionally create `Notinhas/Services/Capture/FloatingToolbar/CaptureFloatingScreenClamp.swift`
  **or** promote `clampedOrigin` to `internal`/`package` static API on
  `CaptureFloatingToolbarPlacement` (pick one; prefer a tiny `CaptureFloatingScreenClamp`
  enum if you want a name that future HUD hosts can import without implying
  “placement policy”).
- `NotinhasTests/Services/Capture/CaptureFloatingToolbarPlacementTests.swift`
  and/or a new `CaptureFloatingScreenClampTests.swift`
- `plans/README.md` (status row only)

**Out of scope**:

- Changing `screenEdgeInset`, `outsideSelectionGap`, `insideSelectionBottomInset`,
  or `interToolbarGap` values
- Merging `InlineAreaControlGeometry` with `CaptureFloatingToolbarPlacement`
- Editing InlineArea prefer-above / action-rail layout
- Adopting the origin clamp inside InlineArea **unless** a call site is proven
  identical (same reversed-range → `minimum` semantics). Default: **do not**
  touch `InlineAreaAnnotateWindow.swift`
- Cursor exclusion (plan 059)
- Visual material / button size changes

## Git workflow

- Branch: `advisor/060-capture-floating-screen-clamp`
- Commit style: `refactor: …` / `test: …`
- Do NOT push/PR unless instructed

## Steps

### Step 1: Extract named clamp with identical behavior

Move the private `clampedOrigin` body to a shared symbol, e.g.:

```swift
enum CaptureFloatingScreenClamp {
  /// Clamps a leading/trailing origin into `[minimum, maximum]`.
  /// When the toolbar cannot fit (`maximum < minimum`), returns `minimum`
  /// so the leading edge stays on-screen.
  static func clampedOrigin(_ origin: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat { ... }
}
```

Update `CaptureFloatingToolbarPlacement.frameOrigin` to call that symbol.
**Do not** change any numeric constants or prefer-below logic.

**Verify**:
`./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests`
→ exit 0; all existing assertions still pass **without** expectation edits.
If any expectation must change, STOP — behavior drifted.

### Step 2: Add explicit reversed-range unit tests

If existing tests already cover oversized toolbars, add 1–2 direct tests on
`CaptureFloatingScreenClamp.clampedOrigin` (or the promoted API):

- `maximum >= minimum`: normal clamp
- `maximum < minimum`: returns `minimum`
- Equal bounds: returns that bound

**Verify**: same test command including any new test class → exit 0.

### Step 3: Document non-adoption of InlineArea

In a short comment on `CaptureFloatingScreenClamp` (or above the placement
`clampedOrigin` call), note that Capture Markup’s
`InlineAreaControlGeometry` center clamp uses a mid-frame fallback on inverted
ranges and must not be replaced by this helper without an explicit product
decision.

Do **not** edit `InlineAreaAnnotateWindow.swift` in this plan.

**Verify**: `git diff --name-only` shows no `InlineAreaAnnotateWindow.swift`.

## Test plan

- Keep all `CaptureFloatingToolbarPlacementTests` green with **zero** expectation
  changes (behavior lock).
- Add direct clamp tests for reversed-range (Step 2).
- No manual UI gate required if placement tests pass unchanged; optional spot
  check All-In-One HUD still clamps at screen edges.

## Done criteria

- [ ] Shared clamp symbol exists; `CaptureFloatingToolbarPlacement` uses it
- [ ] `./scripts/run-tests.sh -only-testing:NotinhasTests/CaptureFloatingToolbarPlacementTests` exits 0
- [ ] Existing placement test expectations unchanged
- [ ] `InlineAreaAnnotateWindow.swift` untouched
- [ ] `plans/README.md` status row for 060 updated

## STOP conditions

Stop and report back (do not improvise) if:

- Drift / placement test expectations must change to pass.
- Reviewer pressure to “also wire InlineArea to the shared clamp” without proving
  identical inverted-range semantics.
- Request to unify prefer-above Markup placement with prefer-below HUD placement.
- Verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Future floating HUD hosts should clamp origins with
  `CaptureFloatingScreenClamp` (or the promoted API), not copy-paste.
- Reviewers: reject PRs that change gaps/insets or Markup layout under this plan’s
  banner.
- Deferred intentionally: visual chrome bridge (materials), diagonal resize cursor
  image sharing, any Capture Markup ↔ All-In-One hosting merge.
