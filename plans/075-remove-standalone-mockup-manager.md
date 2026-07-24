# Plan 075: Delete orphaned standalone MockupManager window path

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat a6128271..HEAD -- Notinhas/Features/Annotate/Managers/AnnotateMockupManager.swift Notinhas/Features/Annotate/Components/AnnotateMockupMainView.swift Notinhas/Features/Annotate/Models/AnnotateMockupState.swift NotinhasTests/Features/Annotate/AnnotateMockupTests.swift`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `a6128271`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — touches Annotate mockup files adjacent to live editorMode.mockup
- **Reviewer required**: `yes` — easy to delete integrated mockup by mistake
- **Rationale**: Must surgically remove standalone `MockupState` window stack while keeping Annotate `editorMode.mockup`.
- **Escalate when**: Call sites for `MockupManager` appear outside the manager file, or integrated mockup shares types unexpectedly.

## Why this matters

`MockupManager.shared` / `openMockup` / `openEmptyMockup` have **zero call sites** outside `AnnotateMockupManager.swift`. They open a separate `MockupMainView` window on a parallel `MockupState` object. The live product path is Annotate’s `EditorMode.mockup` (bottom-bar mode picker + `MockupControlsSection` on `AnnotateState`). Dead standalone code confuses agents into treating mockup as a second app surface.

## Current state

Standalone entry (dead):

```13:40:Notinhas/Features/Annotate/Managers/AnnotateMockupManager.swift
final class MockupManager {
  static let shared = MockupManager()
  ...
  func openMockup(for image: NSImage) { ... }
  func openMockup(from url: URL) { ... }
  func openEmptyMockup() { ... }
```

`MockupMainView` hosts `MockupToolbarView` + `MockupSidebarView` + `MockupCanvasView` + `MockupPresetBar` on `MockupState`.

**Live (KEEP)** integrated path:
- `AnnotateBottomBarView` — `.tag(AnnotateState.EditorMode.mockup)` + `MockupPresetBarInline(state:)`
- `AnnotateSidebarView` — `MockupControlsSection(state:)` when `editorMode == .mockup`
- `AnnotateState.applyMockupPreset`, mockup rotation fields, `AnnotateMockupTransformModifier`, `MockupPreset` / `DefaultPresets`
- Tests: ALWAYS-RUN `AnnotateState` mockup preset tests in `AnnotateMockupTests.swift`

**Standalone-only (DELETE)** — only referenced from MockupMainView / MockupState stack:
- `AnnotateMockupManager.swift` (`MockupManager`)
- `AnnotateMockupMainView.swift` (`MockupMainView`, `MockupToolbarView`)
- `AnnotateMockupSidebarView.swift` (`MockupSidebarView`)
- `AnnotateMockupCanvasView.swift` (`MockupCanvasView`)
- `AnnotateMockupPresetBar.swift` (`MockupPresetBar` — **not** `AnnotateMockupPresetBarInline.swift`)
- `AnnotateMockupExporter.swift` (`MockupExporter` for `MockupState`)
- `AnnotateMockup3DRenderer.swift` (`Mockup3DRenderer` for `MockupState`)
- `AnnotateMockupState.swift` (`MockupState`)

**KEEP files**:
- `AnnotateMockupPreset.swift`, `AnnotateDefaultPresets.swift`
- `AnnotateMockupPresetBarInline.swift`
- `AnnotateMockupControlsSection.swift`
- `AnnotateMockupTransformModifier.swift`
- Annotate exporter paths that use `AnnotateState` mockup fields

Before delete, re-confirm with:

```bash
rg -n 'MockupManager|MockupMainView|MockupState|MockupExporter|MockupCanvasView|MockupSidebarView|MockupPresetBar[^I]|Mockup3DRenderer' Notinhas NotinhasTests --glob '*.swift'
```

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Call-site check | `rg -n 'MockupManager\.shared|openMockup|openEmptyMockup' Notinhas --glob '*.swift'` | only manager file (then none after delete) |
| Focused tests | `./scripts/run-tests.sh -only-testing:'NotinhasTests/AnnotateMockupTests' -only-testing:'NotinhasTests/AnnotateCoreTests/testMockupPresetCatalogContainsUniqueBuiltInPresets'` | pass (adjust selector syntax to match `run-tests.sh` — if unsupported, run `./scripts/run-tests.sh --skip-visual` and confirm AnnotateMockupTests) |
| Build | Prefer `./scripts/run-tests.sh --skip-visual` after deletions | exit 0 or only known pre-existing flakes unrelated to mockup |

If `run-tests.sh` does not support `-only-testing`, use:

```bash
./scripts/run-tests.sh --skip-visual
```

and confirm Annotate mockup-related tests pass in the log.

## Scope

**In scope**:
- Delete the standalone-only Swift files listed above
- Update `NotinhasTests/Features/Annotate/AnnotateMockupTests.swift` — remove `MockupState` / `MockupExporter` test methods and retainedMockupStates helpers; **keep** `AnnotateState` applyMockupPreset / reset tests and file header comments updated
- Update any docs that describe a standalone mockup window (unlikely)
- `project.pbxproj` only if deleted files are explicitly referenced (many setups use folder sync — only edit if build fails on missing references)

**Out of scope**:
- Removing `EditorMode.mockup` from Annotate
- Watermark / Combine / Video
- Plan 078 product decisions about hiding mockup mode

## Git workflow

- Branch: `advisor/075-remove-standalone-mockup-manager`
- Commit: `refactor: remove unused standalone MockupManager window`
- Do NOT push unless instructed.

## Steps

### Step 1: Prove zero external call sites

```bash
rg -n 'MockupManager\.shared|openMockup\(|openEmptyMockup\(' Notinhas NotinhasTests --glob '*.swift'
```
→ matches only inside `AnnotateMockupManager.swift`. If any other file matches, STOP.

### Step 2: Map KEEP vs DELETE with rg

Run the full symbol `rg` from Current state. Classify every hit. If `MockupState` is imported by a KEEP Annotate path you did not expect, STOP.

### Step 3: Delete standalone files

Delete the DELETE list files. Do **not** delete Inline / Controls / Transform / Preset / DefaultPresets.

**Verify**: `test ! -f Notinhas/Features/Annotate/Managers/AnnotateMockupManager.swift`

### Step 4: Trim tests

Edit `AnnotateMockupTests.swift`:
- Keep AnnotateState preset/reset tests
- Remove MockupState clamping / MockupExporter GPU tests and `retainedMockupStates`
- Update file header to say standalone MockupState path was removed

Keep `testMockupPresetCatalogContainsUniqueBuiltInPresets` in AnnotateCoreTests.

### Step 5: Build/test

Run `./scripts/run-tests.sh --skip-visual` (or focused selectors if available).

**Verify**: compile succeeds; Annotate mockup AnnotateState tests pass.

## Test plan

- Characterization already exists for AnnotateState presets — keep them.
- New tests not required beyond ensuring deletions do not leave broken references.
- Pattern: existing `AnnotateMockupTests` AnnotateState section.

## Done criteria

- [ ] `MockupManager` / `MockupMainView` / `MockupState` types gone from Notinhas/
- [ ] `MockupPresetBarInline` + `EditorMode.mockup` still present
- [ ] `rg -n 'MockupManager|MockupState' Notinhas --glob '*.swift'` → no matches
- [ ] `./scripts/run-tests.sh --skip-visual` compiles and Annotate mockup AnnotateState tests pass
- [ ] No unrelated files modified

## STOP conditions

- Any call site opens MockupManager from App/menu — STOP (not orphaned).
- Deleting MockupState breaks integrated mockup compile — STOP and restore; reassess shared types.
- Test failure in non-mockup areas that you did not touch — report; do not “fix” broadly.

## Maintenance notes

- Integrated mockup remains until a product decision (plan 078) says otherwise.
- Reviewers: diff must not remove `MockupPresetBarInline` or `EditorMode.mockup`.
- Thermo-nuclear review recommended after merge.
