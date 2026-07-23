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
| 038 | Refine All-In-One chrome and add delayed area capture | P1 | M | 035–037 | DONE (`c97eef68`; automated gates and manual smoke complete) |

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
| 041 | Remove rectangular backing from the All-In-One floating HUD | P1 | M | 039, 040 | DONE (`d03b1d97`; thermo review: no code findings; host/placement tests and Video-off/Video-on builds pass; manual visual gate pending display permission) |

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

## All-In-One resize snapping (042)

The All-In-One refinement now exposes native resize cursors on all eight
handles and resolves semantic, visual, and captured-color boundaries while
resizing. The attraction defaults to 5 px, is configurable in Capture
preferences, and immediately yields when the raw edge crosses the candidate.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 042 | Add native resize affordances and content-aware snapping to area refinement | P1 | L | 036, 040 | DONE (`044a0e9b`; review fixes `73d128c1`; manual Screen Recording/Accessibility smoke pending) |

### Validation note (042)

Focused snapping, geometry, AX, and configuration tests pass; the default
Video-off build and full `./scripts/run-tests.sh --skip-visual` suite pass.
CatalogTool verification remains blocked by its pre-existing hardcoded
`Snapzy/Resources/Localization/manifest.json` path; the repository's manifest
is under `Notinhas/Resources/Localization/manifest.json`.

## Capture preferences organization (043)

Plan 043 unifies the nested General and Screenshot panes into one Capture flow
ordered by capture environment, selection, screenshot behavior, specialized
capture, output, post-processing, and after-capture actions. The optional
Recording pane remains separate and conditional on the Video module.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 043 | Unify General and Screenshot preferences into one Capture flow | P1 | M | — | DONE |

### Dependency notes (043)

- 043 is independent of the completed All-In-One plans, but it must preserve
  their All-In-One-only Selection Snapping controls and descriptions.
- 043 is a presentation/documentation change only; it must not migrate or
  rename persisted UserDefaults or TOML keys.

## Cloud ImgBB configuration (044)

Plan 044 moves ImgBB API-key configuration into Preferences → Cloud as an
independent Image Sharing section backed by Keychain, migrates legacy
`notinhas.imgbb.apiKey` UserDefaults on read, and keeps manual Annotate/Quick
Access uploads separate from `CloudProvider` and Cloud Upload History.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 044 | Migrate ImgBB configuration into the Cloud preferences flow | P1 | M | — | DONE |

### Dependency notes (044)

- 044 coordinates manual Cloud/Annotate UI smoke with plan 043 when both land in
  the same round; functional scope remains independent.
- 044 must not add `.imgbb` to `CloudProviderType`, Cloud Upload History, or
  `.notinhascloud` archives.

## Capture freeze and multi-display behavior (045)

Plan 045 makes Freeze Screen apply to All-In-One selection/refinement and to
all connected displays. It reuses one `FrozenAreaCaptureSession` across the
selection and final crop, preserves the live path when the preference is off,
and keeps Timer fresh at fire time. Fullscreen, Scrolling, and Recording remain
outside this screenshot-area behavior.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 045 | Honor Freeze Screen in All-In-One and freeze every connected display | P1 | L | — | DONE |

## All-In-One cursor regression (046)

Plan 046 restores resize-cursor delivery after the frozen backdrop host was
introduced. It keeps the frozen pixels visible while making the backdrop's
window level explicitly lower than the selection overlays and adds the narrow
automated contract plus the required manual WindowServer cursor gate.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 046 | Restore All-In-One resize cursors over frozen backdrops | P1 | M | 042, 045 | DONE (`ce1066fa`; automated gates and manual WindowServer cursor gate complete) |

### Dependency notes (046)

- 046 depends on 042 for the existing eight-handle geometry/cursor mapping and
  on 045 for the frozen backdrop host that introduced the regression.
- The automated level/geometry tests are necessary but insufficient; the
  physical cursor gate must be run with the real All-In-One overlays visible.

### Dependency notes (045)

- 045 is independent of 043 and 044 at the source level, but its final manual
  Preferences/Capture smoke checks should be serialized with 043.
- 045 must preserve the existing `FrozenAreaCaptureSession` composite crop and
  must not turn ImgBB/Cloud or unrelated capture modes into dependencies.

## Local delivery automation (047–051)

This round intentionally excludes CI, GitHub Actions, hosted runners, and PR
gates. The project is personal and local, but versioning discipline remains
mandatory: every implemented plan still requires commit, merge, cleanup, push,
and integrated review. These plans automate mechanical preparation and
evidence collection around that discipline; they do not remove any Git gate.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 047 | Add a local preflight command for implementation plans | P1 | M | — | DONE (`d15cb500`; executor `90ce86c5`; 20 fixtures pass; thermo review approved) |
| 048 | Select local verification from the changed surface | P1 | M | 047 | DONE (`6f22343f`; executor `8a29df2e`; 25 fixtures pass; review fix `fee4fe08`) |
| 049 | Automate the mandatory local Git integration protocol | P1 | M | 047, 048 | DONE (`db852f45`; 22 executor fixtures, 23 after review fix `d22678d4`) |
| 050 | Make build_and_run the sole local launch implementation | P2 | S | — | DONE (`6af68793`; executor `b201ff5d`; syntax/help/verify gates pass) |
| 051 | Make the local TCC test isolated and auditable | P2 | M | — | DONE (`a8470d9c`; executor `930c9893`; review fix `ed460b60`; automated safety gates pass, manual TCC flow remains) |

### Dependency notes (047–051)

- 047 establishes the preflight/evidence contract consumed by 048 and 049.
- 048 must land before 049 so Git integration can require a resolved local
  verification report rather than relying on agent memory.
- 050 and 051 are independent local workstreams and can be executed separately.
- None of these plans changes CI or removes mandatory commit, merge, cleanup,
  push, or integrated-review stages.

## Notinhas editor ergonomics (052)

The next focused Notinhas change addresses a visual-handoff friction point:
the contextual note editor can cover image evidence while the user writes a
comment. It is separate from the right-side summary panel and must remain
transient UI state, outside the exported composition.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 052 | Make the Notinhas contextual editor freely draggable | P1 | M | — | DONE (e0376193) |

### Dependency notes (052)

- 052 is independent of the completed capture, preferences, cloud, and local-delivery rounds.
- The plan must preserve the existing `NotinhasNoteGeometry.editorOrigin` automatic first-placement policy while adding a separate UI-space clamp for the transient dragged position.
- The editor box must stay inside the center editing area and must not alter the side-panel summary, persisted note session, undo history, export, or clipboard render.

## Preferences numeric controls (053)

The Preferences audit found 13 direct sliders across Capture, Quick Access, and
History. They share stepped values but not the same semantics: scalar visual
settings benefit from slider + exact value + `−/+`, finite scale settings
are clearer as explicit choices, and History counts/retention need precise
Stepper/numeric editing because zero means unlimited/forever. This follow-up
extends the shared control shipped by Plan 034 without widening that plan into
VideoEditor or Annotate.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 053 | Standardize Preferences numeric controls with stepped sliders and discrete alternatives | P1 | L | — | DONE (`047dbd1f`; review fix `2f7adb48`) |

### Dependency notes (053)

- 053 is independent of Plan 052 and the completed capture/local-delivery rounds.
- 053 reuses the shared `SteppedSliderControl` from Plan 034, but it must not
  modify Annotate/Notinhas call sites or introduce VideoEditor/Recording scope.
- The scalar slider adoption should be validated before the History numeric
  field/Stepper migration because the latter has special zero-value semantics.

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
- Treating all Preferences values as sliders: rejected for Plan 053; Quick
  Access finite scale choices and History exact/special-value counts have
  clearer Picker or numeric Stepper semantics.
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
- CI workflow optimization: intentionally excluded from plans 047–051 because
  the maintainer explicitly deferred hosted CI and PR automation for this
  personal local fork.
- Removing merge or push from the delivery protocol: rejected — versioning
  discipline remains mandatory even for local use; only the mechanical protocol
  is being automated.

## Global macOS skill overlay adoption

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 054 | Adopt global macOS skills with Notinhas overlays | P1 | M | global plan 004 merged | DONE |

Execute 054 only after the canonical global skill bundle is merged. Preserve
`capture-annotate-export`, `plan-execute-review`, and `project-standards` as
Notinhas-local specialists; migrate only the seven cross-project skills.

## All-In-One capture visual polish (055)

Generated 2026-07-23 against commit `8ae2567c`. Removes the continuous white
selection stroke (keeps handles) in All-In-One refinement, restyles the
dimensions HUD to match the mode strip, and places dimensions always to the
right of the mode strip with a 16pt gap and equal height.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 055 | Polish All-In-One selection chrome and side-by-side HUD layout | P1 | M | — | DONE (`2437ce5c`; review fixes in `7c617bf8`; manual All-In-One visual gate PENDING) |

### Dependency notes (055)

- 055 is independent of completed rounds 035–054; it refines chrome/layout shipped
  by the All-In-One capture work (035–041).
- Do not reopen settled decisions in the plan (no order invert, no vertical stack,
  no `AreaSelectionWindow` border change).

### Findings considered and rejected (055 round)

- Removing the white border during initial area drag (`AreaSelectionWindow`):
  deferred — out of scope; only All-In-One refinement chrome.
- Flipping dimensions to the left of the mode strip when near the trailing screen
  edge: rejected by product decision — clamp/pin the pair; never invert.
- Vertically stacking HUDs when the pair does not fit: rejected — never stack.

## Annotate interaction regressions (056–058)

Generated 2026-07-23 against commit `b7a76965` (plans authored on
`84be0955`; Planned-at refreshed after indexing). Observed while manually
verifying plan 055, but **not caused by 055** (All-In-One capture chrome).
Likely noticed after plan 052 (contextual editor free-drag). Three fix plans:
editor placement tremble, annotate shape + Notinhas marker drag-start hitch,
and Quick Access hover chrome inconsistency.

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 056 | Stabilize Notinhas contextual editor placement (stop tremble) | P1 | M | — | TODO |
| 057 | Remove annotate shape and Notinhas marker drag-start hitch | P1 | M | — | TODO |
| 058 | Restore reliable Quick Access hover action chrome | P2 | M | — | TODO |

### Dependency notes (056–058)

- **056 ∥ 057**: parallel — different folders (Notinhas overlay placement vs
  `AnnotateCanvasDrawingView` / marker move publishing).
- **058**: technically parallel, priority P2 — land after or beside 056/057
  when bandwidth allows; no code dependency on them.
- Do **not** attribute these fixes to plan 055 or reopen All-In-One chrome.

### Findings considered and rejected (056–058 round)

- Blaming plan 055 for editor tremble / shape hitch / QA hover: rejected —
  055 touches All-In-One HUD/overlay files only; symptoms live on Annotate /
  Notinhas / Quick Access paths (052 for editor drag).
- One mega-plan covering all three symptoms: rejected — separate roots.
- Separate plans for shape hitch vs marker hitch: rejected — shared canvas
  invalidation / publish story; one plan (057).
- Separate Quick Access characterization spike before fixing: deferred unless
  the targeted B/D fixes in 058 fail the manual checklist.
- Instruments time-profile as a hard done gate for 057: deferred — manual
  hitch gate + invalidation contract tests are enough.
- Raising Quick Access above Annotate or making QA a key window: rejected.
