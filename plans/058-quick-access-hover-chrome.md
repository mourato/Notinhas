# Plan 058: Restore reliable Quick Access hover action chrome

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat b7a76965..HEAD -- Notinhas/Features/QuickAccess/Components/QuickAccessCardView.swift Notinhas/Features/QuickAccess/QuickAccessPanel.swift Notinhas/Features/QuickAccess/QuickAccessManager.swift Notinhas/Features/QuickAccess/Managers/QuickAccessPanelController.swift docs/QUICK_ACCESS.md NotinhasTests/Features/QuickAccess`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED — mouse-passthrough + nonactivating panel hover is historically fragile; wrong self-heal can steal clicks from apps underneath.
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `b7a76965`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `yes` — independent workstream from plans 056 and 057 (different feature folder). Prefer landing after P1 Annotate fixes if the operator serializes bandwidth.
- **Reviewer required**: `yes` — passthrough regressions are easy to miss in CI and painful in daily use.
- **Rationale**: Touches AppKit event monitors and SwiftUI hover state; needs careful manual gates.
- **Escalate when**: the fix seems to require making Quick Access a key window, changing Annotate window levels, or adding a permanent CGEvent tap.

## Why this matters

Quick Access cards should reveal configured action buttons on hover. Users now see inconsistent behavior: sometimes hovering shows nothing, including cases with **no Annotate window open**, and cases where the card **reappears under a stationary cursor** after closing Annotate. That breaks the post-capture handoff affordance. This plan fixes the two strongest code-backed failure modes without redesigning Quick Access actions or preferences.

## Current state

Docs already name the monitor-death failure mode:

```10:10:docs/QUICK_ACCESS.md
- Mouse monitors suspended during area capture (`suspendForCapture()` → panel + pin windows). Self-heal: `setWindowOpen(isOpen: false)` (editor window closed) reinstalls the panel's monitors — macOS can silently disable the global event tap after a runloop stall, which otherwise leaves hover dead.
```

Panel API:

```53:61:Notinhas/Features/QuickAccess/QuickAccessPanel.swift
  /// Reinstall monitors after a runloop stall. macOS can silently disable the global
  /// event tap when delivery stalls (no re-enable notification reaches the app),
  /// which leaves hover dead until the monitors are recreated. No-op while suspended
  /// (e.g. during an active capture session).
  func reinstallMouseMonitors() {
    guard !isMonitorsSuspended else { return }
    removeMouseMonitors()
    installMouseMonitors()
  }
```

Self-heal today runs **only when an editor closes**:

```680:684:Notinhas/Features/QuickAccess/QuickAccessManager.swift
      if !isOpen {
        // An editor window just closed and the card reappeared: self-heal the
        // hover monitors in case the runloop stall got the global event tap killed.
        panelController.reinstallMouseMonitors()
      }
```

Card hover chrome is gated on SwiftUI `@State isHovering`, which is forced **false** on appear/disappear — with **no** re-prime when the pointer is already over the card:

```109:142:Notinhas/Features/QuickAccess/Components/QuickAccessCardView.swift
    .onHover { hovering in
      withAnimation(QuickAccessAnimations.hoverOverlay) {
        isHovering = hovering
      }
      ...
    }
    ...
    .onAppear {
      ...
      isHovering = false
    }
```

Buttons still require `canPerformCardActions` and non-empty configured overlay/corner actions — empty configuration is **not** a bug to “fix” by inventing defaults.

Existing synthetic mouse-moved pattern elsewhere (reuse the idea, do not copy blindly into the wrong window):

```242:263:Notinhas/Features/Capture/CaptureViewModel.swift
      // Force cursor tracking re-evaluation on restored windows.
      // orderFront does not trigger mouseEntered, so if the mouse is
      // already over a restored window, tracking areas won't fire ...
      DispatchQueue.main.async {
        let mouseLocation = NSEvent.mouseLocation
        if let syntheticEvent = NSEvent.mouseEvent(
          with: .mouseMoved,
          ...
        ) {
          NSApp.postEvent(syntheticEvent, atStart: false)
        }
      }
```

Window levels (do not change): Quick Access `.floating`; focused Annotate `.floating + 1` (Annotate correctly wins hit-testing when overlapping).

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Quick Access core tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/QuickAccessCoreTests` | Exit 0 |
| Panel controller tests | `./scripts/run-tests.sh -only-testing:NotinhasTests/QuickAccessPanelControllerTests` | Exit 0 (may skip under Reduce Motion / no screen) |
| Default suite without visual flashes | `./scripts/run-tests.sh --skip-visual` | Exit 0 |
| Debug build | `xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO` | Exit 0 |
| Diff hygiene | `git diff --check` | Exit 0 |
| Format | `swiftformat Notinhas/Features/QuickAccess NotinhasTests/Features/QuickAccess` | Exit 0 |

Note: some QA panel tests are on-screen / motion-sensitive. Prefer pure logic tests for new helpers; keep `--skip-visual` green.

## Suggested executor toolkit

- `menubar` / `macos-app-engineering` — nonactivating panel + event monitor caution.
- `.agents/skills/debugging-diagnostics` — capture/TCC context if hover seems permission-related (it usually is not).
- `.agents/skills/testing-xctest` — extend `QuickAccessCoreTests` for pure helpers.
- Update `docs/QUICK_ACCESS.md` briefly when self-heal semantics change.

## Scope

**In scope**:

- `Notinhas/Features/QuickAccess/Components/QuickAccessCardView.swift`
- `Notinhas/Features/QuickAccess/QuickAccessPanel.swift`
- `Notinhas/Features/QuickAccess/QuickAccessManager.swift`
- `Notinhas/Features/QuickAccess/Managers/QuickAccessPanelController.swift` — only if reinstall/show hooks belong there.
- `docs/QUICK_ACCESS.md` — document the new self-heal / hover re-prime behavior in 2–4 bullets.
- `NotinhasTests/Features/QuickAccess/*` — characterization for pure helpers (interactive hit, hover seed policy).
- `plans/README.md` — status row.

**Out of scope**:

- Redesigning Quick Access actions, slots, or Preferences UI (plan 053 territory).
- Changing Annotate / pin window levels.
- Making the QA panel key/main.
- “Fixing” empty overlay when the user disabled/unassigned all actions.
- Annotate editor tremble (056) or shape/marker hitch (057).
- Broad capture-suspend monitor bugs unless a one-line resume hole is proven while implementing — if `suspendForCapture` without resume is found, STOP and report as a separate finding rather than expanding this plan silently.

## Git workflow

- Branch: `implement/058-quick-access-hover-chrome`.
- Commit style: `fix(quickaccess): restore hover actions after remount and monitor death`.
- Do not push or open a PR unless asked.

## Steps

### Step 1: Re-prime hover when a card appears under the cursor

In `QuickAccessCardView` (and/or panel controller after card remount):

1. After `onAppear` resets `isHovering = false`, schedule a **same-run-loop-async** check: if the card’s screen frame contains `NSEvent.mouseLocation` **and** the panel is accepting mouse events for that point, set `isHovering = true` (with the existing hover animation) and invoke the existing `onHover` / countdown pause path consistently.
2. Alternatively or additionally: post a synthetic `.mouseMoved` targeted so the panel’s monitors + SwiftUI `onHover` re-evaluate — mirror the `CaptureViewModel` intent, but keep it scoped to Quick Access (test hook optional, like `onPostSyntheticMouseEvent`, only if needed for XCTest).
3. Ensure remount after `setWindowOpen(false)` (card reappears) hits this path.

**Verify**: Debug build exits 0. Unit-test any pure “shouldSeedHover(mouse:cardFrame:)” helper in `QuickAccessCoreTests`.

### Step 2: Broaden mouse-monitor self-heal beyond editor-close

Today self-heal only runs when `setWindowOpen(..., false)`. Extend safely:

1. Reinstall monitors when the panel is shown / ensured visible (`showPanelIfNeeded` / controller `show`), still no-op while `isMonitorsSuspended`.
2. Reinstall when the visible card stack changes in ways that remount cards (e.g. `isWindowOpen` transitions), not only on close — so sibling cards while Annotate is open can recover without waiting for editor close.
3. Optional narrow heartbeat: at most one delayed reinstall after a card appear (e.g. next main-queue turn), **not** a tight timer loop. STOP if you feel you need a repeating timer — report instead.
4. After reinstall, call `refreshMousePassthrough()` so `ignoresMouseEvents` matches the current pointer.

Do **not** disable passthrough permanently. Outside the interactive strip, `ignoresMouseEvents` must remain `true`.

**Verify**: `./scripts/run-tests.sh -only-testing:NotinhasTests/QuickAccessCoreTests` → exit 0. Add tests for any new pure API (e.g. when reinstall is allowed vs suspended).

### Step 3: Docs + format

Update `docs/QUICK_ACCESS.md` to describe:

- Hover re-prime when a card remounts under a stationary cursor.
- Self-heal on panel show / stack remount, not only editor close.

Run `swiftformat` on touched Quick Access paths.

**Verify**: `git diff --check` → exit 0; docs mention both behaviors.

### Step 4: Suite + manual repro checklist

Run `./scripts/run-tests.sh --skip-visual`.

**Manual repro checklist** (must pass after the fix):

| # | Steps | Expected |
|---|---|---|
| B1 | Capture → open Annotate from QA → close Annotate with the pointer **already** resting where the card reappears; **do not move the mouse** | Hover action chrome appears (or appears after the async re-prime without needing a large mouse move) |
| B2 | Same as B1, then nudge the mouse 1–2px if needed | Chrome definitely visible; no permanent dead hover |
| D1 | With **no** Annotate window open, hover a QA card | Center/corner actions appear per Preferences configuration |
| D2 | Capture several shots, leave QA up, switch to another app and back, hover again | Actions still appear (monitors not permanently dead) |
| P1 | Hover **outside** the card stack | Clicks pass through to apps below (passthrough preserved) |
| P2 | Suspend path: start area capture, cancel/complete, hover QA | Monitors resumed; hover works (if resume is already correct, no change) |
| N1 | Negative: disable/unassign all overlay actions in Preferences | Hover may dim/pause countdown but **no** invented buttons |

If B1/D1 still fail after Steps 1–2, **STOP and report** with which checklist rows failed — do not start a broad rewrite; a follow-up spike may be needed.

**Verify**: suite exit 0; checklist rows B1, D1, P1 pass; N1 still holds.

## Test plan

- Pure helper tests in `QuickAccessCoreTests` for hover-seed and/or reinstall eligibility.
- Do not rely on `QuickAccessPanelControllerTests` slide animations for the core hover contract (Reduce Motion skips).
- Manual checklist above is part of done criteria.

## Done criteria

- [ ] Card remount under stationary cursor shows hover chrome without requiring a large mouse move (B1).
- [ ] Hover works with no Annotate window open (D1).
- [ ] Monitor self-heal is not solely tied to `setWindowOpen(false)`; panel show / remount also heals (code + docs).
- [ ] Passthrough outside cards preserved (P1).
- [ ] Empty/disabled action config still shows no invented buttons (N1).
- [ ] `./scripts/run-tests.sh -only-testing:NotinhasTests/QuickAccessCoreTests` exits 0.
- [ ] `./scripts/run-tests.sh --skip-visual` exits 0.
- [ ] Debug build + `git diff --check` exit 0.
- [ ] `docs/QUICK_ACCESS.md` updated; `plans/README.md` status updated.

## STOP conditions

- Fix requires making Quick Access key/main or raising it above Annotate.
- Fix requires a repeating poll/timer to keep monitors alive.
- Checklist B1/D1 still fail after the two targeted fixes — stop for a separate characterization spike.
- You discover `suspendForCapture` without `resumeAfterCapture` as the dominant bug — report as a new finding; only fix it here if it is a one-line hole in an already-touched resume path.
- Drift mismatch on the cited hover/monitor code.
- Verification fails twice after a reasonable attempt.

## Maintenance notes

- Future editor open/close animations must keep a single animation driver (`QuickAccessStackView`) and still remount-prime hover.
- Reviewers: watch for click-stealing (`ignoresMouseEvents = false` too often) and for synthetic mouse events spamming the app.
- Deferred: deep Instruments on global event-tap lifetime; Annotate-overlap occlusion (by design while frames overlap).
