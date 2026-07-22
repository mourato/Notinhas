# Implementation Plans

This directory contains the improve-skill handoff plans. Plans 001–025 are
completed historical Notinhas UX/video work. The identity-separation round is
026–030. The OverlayTooltip rollout + slider steppers round is **031–034**,
generated on 2026-07-21 against commit `df25f56f`. The All-In-One capture
round is **035–037**, generated on 2026-07-22 against commit `1849b93a`.

Execute active rounds with the project skill
`.agents/skills/plan-execute-review/SKILL.md` (Composer 2.5 executor → merge →
thermo-nuclear review → fix all findings → next plan).

## Historical plan status

| Plan | Title | Status |
|---|---|---|
| 001 | Add the Notes editor extension | DONE |
| 002 | Export a Notes composition and preference | DONE |
| 003 | Upload Notinhas output to Imgur | SUPERSEDED — shipped as ImgBB |
| 004 | Draw Notinhas pin numerals upright | DONE |
| 005 | Make exported Notes panel text readable on light background | DONE |
| 006 | Move and delete Notinhas pins while Note is active | DONE |
| 007 | Redesign note editor modal with live style updates | DONE |
| 008 | Show export-parity composition in Preview | DONE |
| 009 | Per-note Notinhas pin size | DONE |
| 010 | Rebase existing agent skills | DONE |
| 011 | Add `capture-annotate-export` skill | DONE |
| 012 | Port `project-standards` skill | DONE |
| 013 | ImgBB upload feedback lifecycle | DONE |
| 014 | Guard ImgBB button without API key | DONE |
| 015 | Keyboard-shortcut hints | DONE — superseded by 019 |
| 016 | Note-tool discoverability tooltip | DONE — superseded by 018 |
| 017 | Arc-like overlay-tooltip component | DONE |
| 018 | Note-tool overlay tooltip | DONE |
| 019 | Note-editor footer overlay tooltips | DONE |
| 020 | Optional Video module gate/build affordances | DONE |
| 021 | Gate app-shell Video entry points | DONE |
| 022 | Hide Video Preferences when disabled | DONE |
| 023 | Gate History/Quick Access/Onboarding for Video | DONE |
| 024 | Compile-time isolation of Recording/VideoEditor | DONE |
| 025 | Document Video workflow and dual-mode verification | DONE |

## Identity-separation execution order

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 026 | Migrate Snapzy data into Notinhas storage | P1 | L | — | DONE (`ba3a2f6`, review fixes `d2c1b57`; full suite has two pre-existing flaky failures) |
| 027 | Remove Sparkle, Report a Problem, and About | P1 | L | 026 | DONE (`db1c0a0`, review fixes `92491f3`; full suite has two pre-existing flaky failures) |
| 028 | Replace `snapzy://` with `notinhas://` | P1 | M | 027 | DONE (`1507d08`; full suite has two pre-existing flaky failures) |
| 029 | Rename the technical product identity to Notinhas | P1 | L | 026–028 | DONE (`6124d74`, review fixes `163e0f1`; focused migration tests and Debug build pass) |
| 030 | Complete documentation and final validation | P2 | L | 029 | DONE (`39f7053`, review fixes `5bc63c6`; docs/scripts residue fixed; default/video suites retain two pre-existing UI failures and Release validation remains environment-blocked) |

Status values: `TODO` | `IN PROGRESS` | `DONE` | `BLOCKED (reason)` |
| `REJECTED (rationale)` | `SUPERSEDED (replacement)`.

## Confirmed product decisions

- Product identity becomes Notinhas, including technical identity where safe.
- Release/debug bundle IDs become `com.mourato.notinhas` and
  `com.mourato.notinhas.debug`.
- Existing data/configuration migrates automatically before database setup.
- Only `notinhas://` is registered/accepted; `snapzy://` is rejected.
- Sparkle, automatic updates, Report a Problem, and About are removed.
- GitHub Releases/DMGs remain manual; cloud, recording, video, and local
  diagnostics remain.
- Screen Recording, Accessibility, and Microphone permissions must be granted
  again after the bundle-ID change because TCC grants cannot be copied.

## Required executor/reviewer loop

Canonical skill: `.agents/skills/plan-execute-review/SKILL.md`.

Every plan requires:

1. Orchestrator dispatches a **Composer 2.5** executor (Cursor) or **GPT 5.6
   Medium** (Codex) in an isolated worktree. If those models are unavailable,
   ask the user which model to use — do not silently substitute.
2. Executor implements only the plan, runs every gate, **commits → merges →
   cleans up worktree/branch → pushes**. If isolation prevents integration,
   the orchestrator completes merge/cleanup/push from the returned commit.
3. Orchestrator runs `/thermo-nuclear-code-quality-review` on the integrated
   diff and **fixes every finding**, commits, and pushes.
4. Only then start the next selected plan.

No executor may silently skip a gate, widen scope, delete legacy data, or
replace a STOP condition with an assumption.

## OverlayTooltip + slider steppers (031–034)

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 031 | Shared Annotate shortcut→keycap helpers + presenter tests | P1 | S | — | DONE (`00178ff3`, review fixes `b120abba`) |
| 032 | OverlayTooltip on Annotate toolbar tools and chrome | P1 | M | 031 | DONE (`fb69b316`, review fixes `f3c5b0fb`) |
| 033 | OverlayTooltip on Annotate bottom-bar shortcut actions | P1 | S | 031 | DONE (`138097e4`; thermo approve, no code fixes; deferred: hardcoded `.help("Move canvas")`) |
| 034 | +/- steppers beside Annotate and Notinhas sliders | P1 | M | — | DONE (`cf041200`, review fixes `44c8836f`) |

### Dependency notes (031–034)

- 031 must land before 032 and 033 (shared `AnnotateOverlayTooltipKeys`).
- 032 and 033 are independent after 031; serialize same-day merges if both
  touch OverlayTooltipPresenter behavior to ease review.
- 034 is independent of 031–033 (parallelizable workstream).
- Preferences / VideoEditor OverlayTooltip and Preferences slider steppers
  were considered and deferred (see rejected findings).

## All-In-One capture (035–037)

CleanShot-style single-shortcut capture HUD: pick mode + refine area, with
W×H, aspect lock, and last-selection restore. Reuses floating-HUD patterns from
Recording/Scrolling without depending on the Video-gated `RecordingToolbarWindow`.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 035 | Shared capture floating HUD chrome (ungated) | P1 | M | — | DONE (`e539d2bf`; thermo fixes `d58843df`) |
| 036 | Refinable selection (handles, W×H, aspect lock, last rect) | P1 | L | 035 | DONE (`15dd97a3`; thermo fixes `adf5d650`) |
| 037 | All-In-One session, shortcut, menu, deeplink, docs | P1 | L | 035, 036 | DONE (`0bcc9145`; thermo fixes `0acd57c7`, tests `47348f62`) |

### Dependency notes (035–037)

- 035 must land first (shared `CaptureFloatingHUDWindow` / placement / icon chrome).
- 036 builds geometry + last-rect + refinement on top of 035 chrome.
- 037 wires coordinator + shortcut/menu/deeplink and must not reimplement 035/036.
- Execute strictly 035 → 036 → 037.

### Product decisions (035–037)

- MVP modes: Area, Fullscreen, Window, Annotate, Scrolling, OCR; Recording only
  when `VideoModuleAvailability.isEnabled`.
- Timer / Smart Element / Object Cutout stay out of the All-In-One strip (dedicated
  entry points remain).
- Classic ⌘⇧4 area capture stays commit-on-mouseup; refinement is All-In-One-owned.
- Last selection uses a new key (`capture.allInOne.lastAreaRect`), not
  `recording.lastAreaRect`.
- Default All-In-One shortcut ships **unbound**, recommended ⌘⇧0.
- All-In-One chrome must compile in the default scheme (Video module off).

## All-In-One refinement (038)

The first shipped All-In-One session is functionally complete but its mode
strip is icon-only and the planned Timer mode was intentionally deferred. The
next focused round keeps the established session/refinement architecture,
retains **Annotate**, and introduces a deliberately bounded delayed-area
capture rather than a new generic timer subsystem.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 038 | Refine All-In-One chrome and add delayed area capture | P1 | M | 035–037 | IN PROGRESS (implementation `c97eef68`; automated gates pass, manual smoke pending) |

### Dependency notes (038)

- 038 depends on 035–037 because it extends their shared HUD, refinement, and
  session-dispatch seams; do not re-extract or replace those foundations.
- This is one cohesive UI/behavior change and should be implemented in one
  isolated worktree and reviewed as one pull request.

### Product decisions (038)

- Keep **Annotate** in the All-In-One strip; it is not replaced by Timer.
- Timer means a fixed **three-second delayed area screenshot**. After Capture,
  the HUD and selection chrome disappear, then Notinhas captures the selected
  rectangle. It is not a recording timer, recurring capture, configurable
  preference, Smart Element mode, or Object Cutout mode.
- Recording stays last and remains conditional on the optional Video module.
- The mode strip presents an icon and concise localized label for every mode;
  its selected state must be legible over varied desktop backgrounds.
- The dimension control remains a compact W × H editor with aspect lock; do
  not add crop presets, a reset menu, or unrelated generic markup controls.

## All-In-One flow correction (039–041)

The review at commit `8fbb0455` found that the shipped 038 implementation still
uses a separate Capture button as the only dispatch trigger, while mode buttons
only change `selectedMode`. It also found a duplicated AppKit/SwiftUI material
stack in the shared HUD host that can expose rectangular/white corners. These
plans correct behavior first, then harden session handoff, then fix the visual
host.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 039 | Make every All-In-One mode button execute its capture | P1 | M | 038 | DONE (`80f3d732`; thermo review: no code findings; focused routing tests and Video-off build pass) |
| 040 | Make All-In-One start with the last area and hand off selection safely | P1 | M | 039 | DONE (`821b1123`; thermo review: no code findings; focused lifecycle/store tests pass; manual WindowServer gate remains environment-dependent) |
| 041 | Remove rectangular backing from the All-In-One floating HUD | P1 | M | 039, 040 | TODO |

### Dependency notes (039–041)

- 039 establishes the direct-action contract and removes the obsolete Capture button.
- 040 depends on that contract because Window and no-rect actions must tear down
  the All-In-One session before starting an existing selection flow.
- 041 is last so material/host changes do not obscure a lifecycle regression and
  can be manually checked against the final toolbar contents.

### Review findings

- `AllInOneCaptureToolbarView.swift:15–20` routes mode buttons to
  `selectMode(_:)`, while `AllInOneActionToolbarView.swift:23–31` owns the only
  capture action. This violates the requested one-button/one-mode interaction.
- `AllInOneCaptureCoordinator.swift:56–61` restores a last rect when available,
  but its no-rect first-drag and Window handoff paths require explicit cleanup
  ordering to avoid nested selection sessions and stale blocking state.
- `CaptureFloatingHUDWindow.swift:33–55` creates an AppKit material host while
  both SwiftUI toolbar roots also call `.captureFloatingToolbarMaterial()`;
  `CaptureFloatingToolbarChrome.swift:66–71` confirms the duplicate background
  ownership. Manual tests are required because the artifact is rendered by
  AppKit/SwiftUI rather than pure geometry code.

### Validation note

The local test runner now mirrors `scripts/build_and_run.sh`: outside CI it
uses `Prisma Local Code Signing`, clears `DEVELOPMENT_TEAM`, and disables the
hardened runtime; CI continues to disable signing. After this adjustment, the
focused command for All-In-One, HUD placement, and coordinator tests passed
with 17 tests. The project still retains its automatic team signing settings
for Xcode/release workflows; the local override is intentionally script-scoped.

## Dependency notes (026–030)

- 026 must land before the bundle-ID/path cutover.
- 027 removes shared Sparkle/preferences/release surfaces before URL and
  physical-renaming work; legacy `[updates]` TOML remains importable.
- 028 owns the external URL contract and explicitly rejects the old scheme.
- 029 performs the physical Xcode/module/bundle rename after runtime contracts
  are stable.
- 030 updates public/agent documentation and performs final build, residue,
  migration, permission, and capture → annotate → clipboard validation.

## Compatibility allowlist

Any remaining Snapzy reference after Plan 030 must be classified as one of:

- legacy migration path or old bundle ID;
- old UserDefaults/TOML/sidecar/credential-archive input;
- external cloud object namespace that must remain readable;
- intentional `snapzy://` rejection test;
- historical content explicitly retained for compatibility.

Active UI, runtime identity, installer defaults, public docs, and agent
instructions may not use this allowlist to retain branding.

## Findings considered and rejected

- Plan 033 leftover `.help("Move canvas")` English string: deferred; plan said leave unless L10n exists.


- App-wide OverlayTooltip replacement of every `.help`: rejected for this
  round — scope is Annotate image-editor chrome first; Preferences/Video/
  menu bar remain discovery via shortcut overlay + Preferences.
- Preferences / VideoEditor slider steppers in the same round: deferred;
  plan 034 establishes the shared control on Annotate/Notinhas first.
- Removing cloud, recording, or video: rejected; the user chose identity and
  upstream-integration separation while preserving existing features.
- Keeping `snapzy://` as an alias: rejected by explicit decision.
- Replacing Sparkle with another updater: rejected; distribution is manual.
- Removing local diagnostics with Report a Problem: rejected; local diagnostics
  remain useful without an upload/support flow.
- Renaming external cloud object prefixes: rejected as unsafe for user data.
- Publishing these plans as GitHub issues: not requested; no issues were created.
- All-In-One depending on `RecordingToolbarWindow`: rejected — file is
  `#if NOTINHAS_VIDEO_MODULE`; extract ungated chrome instead (035).
- Putting Timer in the 035–037 All-In-One MVP: rejected at that time —
  Notinhas had no capture-timer mode (recording annotation timer is unrelated).
  This decision is superseded by the bounded delayed-area Timer in plan 038.
- Putting Smart Element / Object Cutout in the All-In-One strip: deferred — keeps
  the HUD focused; dedicated shortcuts/menu remain.
- Upgrading classic ⌘⇧4 to refine-before-capture in the same round: deferred —
  All-In-One owns refinement first to avoid regressing the fast area path.
- Migrating Scrolling HUD onto shared host in 035: deferred — optional DRY later.
