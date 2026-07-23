# Plan 048: Select local verification from the changed surface

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat d4c52d12..HEAD -- scripts/verify-local.sh scripts/verification-map.tsv scripts/tests/verify-local.sh .agents/skills/delivery-workflow/SKILL.md .agents/skills/testing-xctest/SKILL.md AGENTS.md docs/DEVELOPMENT.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/047-local-plan-preflight.md
- **Category**: tests
- **Planned at**: commit `ac45736c`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — it consumes the evidence/report contract established by 047.
- **Reviewer required**: yes — an incorrect mapping can silently under-verify changes.
- **Rationale**: The command is deterministic, but mapping Swift paths to XCTest identifiers and preserving visual/manual gates requires repository-specific judgment.
- **Escalate when**: the implementation claims semantic dependency analysis, changes XCTest behavior, or replaces the full suite as a merge gate.

## Why this matters

`run-tests.sh` already supports filtered tests, Video-module selection, and a local visual skip list, but an agent must decide which flags and suites to use from prose. This causes either unnecessarily expensive full runs or under-verification when a path is missed. A local changed-surface command should produce an explicit verification plan, execute only deterministic relevant checks by default, and flag manual or unknown coverage instead of pretending it is complete.

This plan is local-only. It does not alter CI, and it does not remove the full-suite or manual gates for risky changes.

## Current state

- `scripts/run-tests.sh:40-52` defines seven visual suite identifiers for `--skip-visual`; `:96-100` converts them into `xcodebuild -skip-testing:` arguments.
- `scripts/run-tests.sh:80-94` switches between `Notinhas`/`Debug` and `Notinhas Video`/`Debug+Video`.
- `scripts/run-tests.sh:161-225` forwards unknown options to `xcodebuild`, including `-only-testing:` selectors.
- `.agents/skills/testing-xctest/SKILL.md:10-15` says pure logic should be automated while AppKit/window lifecycle remains manual.
- `.agents/skills/delivery-workflow/SKILL.md:39-52` defines the current merge gate and says Video validation is required when Recording, Video Editor, or video-gated shell/preferences/history paths change.
- Tests mirror source areas under `NotinhasTests/`, with examples such as `NotinhasTests/Features/Annotate/AnnotateCoreTests.swift` and `NotinhasTests/Services/Capture/AreaSelectionModelsTests.swift`.

The command must be conservative: an unmapped changed file produces `manual-required` and a non-zero result in strict mode. It must never silently downgrade an unknown area to “no tests needed.”

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Syntax | `bash -n scripts/verify-local.sh scripts/tests/verify-local.sh` | exit 0 |
| Help | `./scripts/verify-local.sh --help` | documents `--base`, `--plan-only`, `--strict`, `--full`, `--video-module`, and report output |
| Mapping self-test | `scripts/tests/verify-local.sh` | fixture mapping and conservative-failure cases pass |
| Focused test runner | `./scripts/run-tests.sh -only-testing:NotinhasTests/NotinhasNoteGeometryTests` | selected XCTest passes when run on a configured macOS host |
| Hygiene | `git diff --check` | no whitespace errors |

## Scope

**In scope**:

- `scripts/verify-local.sh` — new changed-surface planner/runner.
- `scripts/verification-map.tsv` — explicit path-to-verification policy.
- `scripts/tests/verify-local.sh` — deterministic mapping tests.
- `.agents/skills/delivery-workflow/SKILL.md` — canonical command routing.
- `.agents/skills/testing-xctest/SKILL.md` — conservative mapping/manual-gate rules.
- `AGENTS.md` — short command reference.
- `docs/DEVELOPMENT.md` — local usage and report interpretation.

**Out of scope**:

- `.github/` workflows or any CI behavior.
- Changes to `scripts/run-tests.sh` skip identifiers except where a compatibility bug is proven and explicitly reported first.
- New application tests unrelated to the verification command.
- Replacing manual Screen Recording, Accessibility, TCC, WindowServer, clipboard, or visual smoke checks.

## Git workflow

- Branch: `advisor/048-local-changed-surface-verification` or the active isolated implementation branch.
- Commit message: `feat: add changed-surface local verification`.
- Merge and push remain mandatory after executor and review gates.

## Steps

### Step 1: Define the verification map

Create `scripts/verification-map.tsv` with columns `glob`, `profile`, `selector`, `manual`, and `reason`. Keep it declarative and avoid shell snippets or `eval`. Include explicit entries for:

- `Notinhas/Features/Notinhas/**` → the existing Notinhas XCTest classes discovered under `NotinhasTests/Features/Notinhas/`.
- `Notinhas/Features/Annotate/**` → matching Annotate test classes.
- `Notinhas/Services/Capture/**` → matching Capture test classes.
- `Notinhas/Features/Recording/**` and `Notinhas/Features/VideoEditor/**` → Video-module profile.
- `scripts/**` → Bash syntax/help checks, not XCTest.
- `docs/**`, `.agents/skills/**`, and `AGENTS.md` → documentation/routing checks only.
- unknown application paths → `manual-required`.

Use exact class identifiers that exist in the repository; do not invent selectors. If a glob maps to a directory but no matching test class exists, mark it `manual-required` rather than running an empty selector.

**Verify**: an `awk`/shell validation from the fixture test confirms every row has five fields, no command field contains executable shell syntax, and all referenced test selectors exist in the current repository.

### Step 2: Implement plan-only mode

Create `scripts/verify-local.sh` with `set -euo pipefail`. It must collect changed paths from an explicit `--base REF` plus staged and unstaged changes, normalize duplicates, match them against the map, and print a stable report containing changed paths, selected profiles, XCTest selectors, shell checks, and manual-required items.

Default mode must be `--plan-only`: it prints the commands it would run and writes an optional report under `build/verification/`. It must not execute tests, builds, or UI actions unless `--execute` is explicitly supplied. `--strict` must fail if any changed path is unmapped or has a manual-required item.

**Verify**: `./scripts/verify-local.sh --help` and `./scripts/verify-local.sh --base main --plan-only` → usage is clear; the second command either prints a valid plan or reports the exact unavailable base ref without mutating files.

### Step 3: Implement execution profiles

Add `--execute` with these rules:

- shell-only changes run `bash -n` and each touched script’s `--help` where help is supported;
- mapped pure-logic changes call `scripts/run-tests.sh` with exact `-only-testing:` selectors;
- Video changes select `scripts/run-tests.sh --video-module`;
- visual/manual changes run the deterministic subset, then exit with a clearly labeled manual gate rather than claiming completion;
- `--full` explicitly delegates to `scripts/run-tests.sh` without changing the default changed-surface behavior.

Use the existing runner instead of duplicating its Xcode signing, DerivedData, result bundle, and log handling. Emit the resolved commands and exit statuses in the report.

**Verify**: `./scripts/verify-local.sh --base main --plan-only --strict` → unknown/manual paths produce a non-zero status; a fixture containing only `scripts/` paths produces shell checks and no XCTest command.

### Step 4: Add fixtures and route documentation

The fixture test must cover changed files for Notinhas, Annotate, Capture, Video, scripts, docs, and an unknown path. It must assert that unknown paths are conservative failures and that `--plan-only` does not create or modify tracked files.

Update `delivery-workflow`, `testing-xctest`, `AGENTS.md`, and `docs/DEVELOPMENT.md` with the new command. State explicitly that the command narrows deterministic local feedback; it does not replace the full suite or manual gates when the affected surface requires them.

**Verify**: `scripts/tests/verify-local.sh && bash -n scripts/verify-local.sh && git diff --check` → all pass.

## Test plan

- Shell fixtures for path normalization, map matching, exact selectors, unknown paths, Video profile selection, and manual-required output.
- `bash -n` for new shell files.
- Plan-only execution against a temporary fixture or a real `--base` ref, without running the full app suite during script unit testing.
- One focused XCTest invocation for a mapped selector after implementation, plus the normal full/visual/manual gate when the actual changed surface requires it.

## Done criteria

- [ ] A changed path produces a deterministic profile and evidence report.
- [ ] Unknown paths fail under `--strict` and are never treated as fully verified.
- [ ] The command reuses `scripts/run-tests.sh` instead of duplicating Xcode invocation logic.
- [ ] `--plan-only` has no tracked-file or Git-state side effects.
- [ ] Video-module selection is explicit and based on changed paths.
- [ ] Manual UI/TCC/WindowServer requirements remain visible in the report.
- [ ] No CI files are modified.
- [ ] Shell fixtures, `bash -n`, and `git diff --check` pass.
- [ ] `plans/README.md` status row for 048 is updated.

## STOP conditions

- A path-to-test mapping cannot be confirmed from existing test identifiers.
- The command would need to infer semantic behavior from source text or use `eval`.
- A manual UI gate would be reported as passed without actually running it.
- The implementation needs to change `run-tests.sh` skip policy without a separate regression plan.

## Maintenance notes

Every new major feature directory must add a map row and a fixture case. Reviewers should inspect the resolved selector list and manual-required list, not only the final exit code. Keep the map local and versioned; do not move it into CI configuration.
