# Plan 031: Shared Annotate shortcut→keycap helpers + OverlayTooltip presenter tests

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**:
> `git diff --stat df25f56f..HEAD -- Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift Notinhas/Features/Annotate/Services/AnnotateShortcutManager.swift Notinhas/Shared/Components/OverlayTooltip/OverlayTooltipPresenter.swift Notinhas/Shared/Components/OverlayTooltip/OverlayTooltipModifier.swift NotinhasTests/Shared/Components/OverlayTooltipPlacementTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: direction (foundation for OverlayTooltip Annotate rollout)
- **Planned at**: commit `df25f56f`, 2026-07-21

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `no` — 032 and 033 depend on the helper API this plan adds
- **Reviewer required**: `yes` — establishes the Annotate OverlayTooltip adoption contract
- **Rationale**: Small shared helpers + unit tests; no UI rollout yet.
- **Escalate when**: helper API grows into a full tooltip framework rewrite, or
  presenter tests require AppKit UI hosting that fails under XCTest headlessly.

## Why this matters

OverlayTooltip already ships (plans 017–019) but Annotate only uses it on the
Notinhas note toolbar button, via a one-off `notinhasNoteShortcutKeys` private
computed property. Plans 032–033 need a single, tested way to turn
`AnnotateShortcutManager` tool keys and action `ShortcutConfig`s into keycap
`[String]` arrays (reusing `ShortcutConfig.displayParts`). Presenter
show/hide owner semantics are also untested — expanding hover tooltips without
that harness risks stuck panels when controls share the singleton presenter.

## Current state

- Only Annotate OverlayTooltip call site today:

```149:164:Notinhas/Features/Annotate/Components/AnnotateToolbarView.swift
    .overlayTooltip(
      NotinhasL10n.noteTool,
      keys: notinhasNoteShortcutKeys,
      secondary: NotinhasL10n.noteToolGestureHint,
      edge: .below
    )
    ...
  private var notinhasNoteShortcutKeys: [String] {
    guard annotateShortcutManager.isShortcutEnabled(for: .notinhasNote),
          let key = annotateShortcutManager.shortcut(for: .notinhasNote)
    else { return [] }
    return [String(key).uppercased()]
  }
```

- Action configs already expose keycap parts:

```141:161:Notinhas/Services/Shortcuts/KeyboardShortcutManager.swift
  var displayParts: [String] {
    var parts: [String] = []
    // … ⌘ ⇧ ⌥ ⌃ fn …
    parts.append(Self.keyCodeToDisplayString(keyCode))
    return parts
  }
```

- Presenter owner hide:

```57:68:Notinhas/Shared/Components/OverlayTooltip/OverlayTooltipPresenter.swift
  func hide(owner: UUID) {
    guard currentOwner == owner else { return }
    currentOwner = nil
    ...
  }
```

- Tests cover placement geometry only:
  `NotinhasTests/Shared/Components/OverlayTooltipPlacementTests.swift` (4 tests).

- Conventions: Conventional Commits (`feat:`, `test:`); SwiftFormat 2-space /
  120 columns; tests under `NotinhasTests/` mirroring app paths; `@MainActor`
  for UI types. Exemplar for manager lookup:
  `NotinhasTests/Features/Annotate/AnnotateShortcutManagerTests.swift`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Format | `swiftformat Notinhas/Features/Annotate Notinhas/Shared/Components/OverlayTooltip NotinhasTests/Shared/Components NotinhasTests/Features/Annotate` | exit 0 |
| Focused tests | `./scripts/run-tests.sh --skip-visual -only-testing:NotinhasTests/OverlayTooltipPlacementTests -only-testing:NotinhasTests/OverlayTooltipPresenterTests -only-testing:NotinhasTests/AnnotateOverlayTooltipKeysTests` | exit 0, all listed suites pass |
| Fallback tests | If `-only-testing` filters fail on the script, run `./scripts/run-tests.sh --skip-visual` and confirm the new test cases pass in the log | exit 0 |

## Suggested executor toolkit

- Skills: `swift-conventions`, `testing-xctest`, `macos-app-engineering`,
  `delivery-workflow`.
- Follow `plan-execute-review` for commit → merge → cleanup → push after done
  criteria pass (orchestrator owns thermo review).

## Scope

**In scope**:
- Create `Notinhas/Features/Annotate/Services/AnnotateOverlayTooltipKeys.swift`
  (or `Notinhas/Shared/Components/OverlayTooltip/AnnotateOverlayTooltipKeys.swift`
  if that keeps Annotate imports cleaner — prefer Features/Annotate/Services)
- Create `NotinhasTests/Features/Annotate/AnnotateOverlayTooltipKeysTests.swift`
- Create `NotinhasTests/Shared/Components/OverlayTooltipPresenterTests.swift`
- Optionally refactor `notinhasNoteShortcutKeys` in `AnnotateToolbarView.swift`
  to call the new helper (keep behavior identical)
- `plans/README.md` status row (unless reviewer maintains index)

**Out of scope**:
- Rolling OverlayTooltip to other toolbar/bottom-bar controls (plans 032–033)
- Changing OverlayTooltip visual design, delay, or placement math
- Preferences / VideoEditor / menu bar
- Slider steppers (plan 034)

## Git workflow

- Branch: `advisor/031-annotate-overlay-tooltip-keys`
- Commit style: Conventional Commits, e.g. `feat(annotate): share overlay tooltip keycap helpers`
- After done criteria: commit, merge into current integration branch (`main`
  unless operator named another), delete worktree/branch, push.
- Do not open a PR unless the operator asks.

## Steps

### Step 1: Add `AnnotateOverlayTooltipKeys` helper

Create a small `@MainActor` enum or struct with static helpers:

```swift
enum AnnotateOverlayTooltipKeys {
  /// Single-key tool shortcuts → `["V"]`, or `[]` when disabled/unset.
  static func toolKeys(
    for tool: AnnotationToolType,
    manager: AnnotateShortcutManager = .shared
  ) -> [String]

  /// Configurable action shortcuts → `ShortcutConfig.displayParts`, or `[]`
  /// when disabled/unset.
  static func actionKeys(
    for kind: AnnotateActionShortcutKind,
    manager: AnnotateShortcutManager = .shared
  ) -> [String]
}
```

Behavior:
- `toolKeys`: mirror `notinhasNoteShortcutKeys` — require
  `manager.isShortcutEnabled(for:)` and a non-nil `manager.shortcut(for:)`,
  then `[String(key).uppercased()]`.
- `actionKeys`: require `manager.isActionShortcutEnabled(for:)` and a non-nil
  `manager.shortcut(for:)`, then `config.displayParts`.

**Verify**: file exists and compiles in isolation conceptually; no callers yet
is OK until step 3.

### Step 2: Unit-test the helper

In `AnnotateOverlayTooltipKeysTests.swift`:

1. With defaults, `toolKeys(for: .rectangle)` returns `["R"]` (default `r`).
2. After `setShortcutEnabled(false, for: .rectangle)`, returns `[]`.
3. After `setShortcut(nil, for: .rectangle)`, returns `[]`.
4. `actionKeys(for: .copyAndClose)` equals
   `AnnotateShortcutManager.defaultCopyAndClose.displayParts` when enabled.
5. After disabling `.copyAndClose`, returns `[]`.

Reset manager state in `tearDown` via `resetToDefaults()` so tests do not leak.

**Verify**: focused test suite passes.

### Step 3: Presenter owner-hide tests

In `OverlayTooltipPresenterTests.swift` (must run on MainActor):

1. Call `show(...)` with owner A and a tiny content / non-zero anchor on
   `NSScreen.main?.visibleFrame` (or a synthetic rect inside main screen).
2. Call `hide(owner: B)` — tooltip must remain (owner mismatch).
3. Call `hide(owner: A)` — tooltip hides (`panel` ordered out / not visible).

If headless XCTest cannot reliably assert `NSPanel` visibility, STOP and report
— do not invent a fake presenter. Prefer asserting `currentOwner` via a
test-only `internal`/`@testable` seam only if already accessible; otherwise
assert panel `isVisible` / `alphaValue` after hide completion (may need a short
expectation for the animation completionHandler).

Keep tests deterministic: use `preferred: .below` and a mid-screen anchor.

**Verify**: presenter tests pass (or STOP with evidence if AppKit panels cannot
be asserted under XCTest — then document and leave a `XCTSkip` with reason
rather than a flaky test).

### Step 4: Point Notinhas note button at the helper

Replace `notinhasNoteShortcutKeys` body with
`AnnotateOverlayTooltipKeys.toolKeys(for: .notinhasNote, manager: annotateShortcutManager)`.
Keep accessibility label logic unchanged.

**Verify**: `swiftformat` on touched paths; focused tests still pass.

### Step 5: Commit / integrate

Commit, merge, cleanup, push per Git workflow. Report MERGE_SHA.

## Test plan

- New: `AnnotateOverlayTooltipKeysTests` (cases above).
- New: `OverlayTooltipPresenterTests` (owner hide semantics; skip cleanly if
  environment cannot host panels).
- Pattern: `AnnotateShortcutManagerTests` for manager reset; existing
  `OverlayTooltipPlacementTests` for XCTest style.
- Verification: focused `./scripts/run-tests.sh --skip-visual` filters above →
  all pass.

## Done criteria

- [ ] `AnnotateOverlayTooltipKeys.toolKeys` / `actionKeys` exist and match the
  behaviors above
- [ ] `notinhasNoteShortcutKeys` delegates to `toolKeys`
- [ ] New XCTest files exist and pass (or presenter suite is `XCTSkip` with a
  clear reason — not a silent no-op)
- [ ] No files outside Scope are modified
- [ ] `swiftformat` on touched paths exits 0
- [ ] Branch merged and pushed; worktree cleaned up

## STOP conditions

- Drift: in-scope excerpts no longer match.
- Presenter tests cannot run without flakiness and no clean `XCTSkip` path —
  report; do not fake green tests.
- Fix appears to require changing OverlayTooltip placement math or bubble UI.
- `AnnotateShortcutManager.resetToDefaults()` is insufficient to isolate tests.

## Maintenance notes

- 032/033 must use these helpers — do not reintroduce one-off key arrays.
- If Preferences later needs the same helpers, keep them Annotate-scoped until
  a second consumer appears.
- Reviewer should confirm disabled shortcuts yield empty `keys` (title-only
  tooltip), matching the note-tool behavior today.
