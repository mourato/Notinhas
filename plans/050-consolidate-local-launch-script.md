# Plan 050: Make build_and_run the sole local launch implementation

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat d4c52d12..HEAD -- scripts/launch.sh scripts/build_and_run.sh AGENTS.md docs/DEVELOPMENT.md .agents/skills/delivery-workflow/SKILL.md`

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `d4c52d12`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: yes — independent from plans 047–049 and 051; workstream is local script consolidation.
- **Reviewer required**: yes — confirm no external caller relies on the legacy script and that behavior remains available through the canonical command.
- **Rationale**: The change is a small shell compatibility decision with clear repository evidence and no application behavior change.
- **Escalate when**: an external local shortcut or undocumented caller depends on launch-specific behavior not represented by `build_and_run.sh`.

## Why this matters

`build_and_run.sh` is the documented and maintained local entry point. `launch.sh` independently kills, builds, discovers products, launches, and streams logs, duplicating an older implementation without the current local signing, optional Video-module, derived-data, and release handling. Keeping both makes agents choose between two command contracts and allows them to drift.

The safest result is one canonical implementation. Because deleting a local script can break an undocumented personal shortcut, preserve the path as a thin compatibility wrapper unless repository evidence proves it is unused and the operator explicitly accepts removal.

## Current state

- `scripts/build_and_run.sh:46-77` documents the canonical modes and options; `:325-395` owns the current Xcode build invocation with local signing overrides and derived data; `:397-403` launches the built app.
- `scripts/launch.sh:23-37` exposes a smaller log-level interface; `:112-131` independently kills, builds, discovers `BUILT_PRODUCTS_DIR`, and launches the binary; `:133-139` streams logs.
- `README.md`, `AGENTS.md`, `docs/DEVELOPMENT.md`, and `delivery-workflow` reference `build_and_run.sh`; repository search found no documentation caller for `launch.sh`.
- `build_and_run.sh` supports `--logs`, `--telemetry`, `--debug`, `--verify`, `--log-level`, `--video-module`, and `--no-video-module`, so the compatibility wrapper can delegate without retaining implementation logic.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Syntax | `bash -n scripts/launch.sh scripts/build_and_run.sh` | exit 0 |
| Canonical help | `./scripts/build_and_run.sh --help` | exit 0 and current options are shown |
| Compatibility help | `./scripts/launch.sh --help` | exit 0 and delegates to the canonical help |
| Reference search | `rg -n "launch\.sh|scripts/launch" README.md AGENTS.md docs .agents scripts --glob '!scripts/launch.sh'` | no unsupported caller remains, or every remaining caller is intentionally documented |
| Hygiene | `git diff --check` | no whitespace errors |

## Scope

**In scope**:

- `scripts/launch.sh` — reduce to a compatibility wrapper or remove only with explicit evidence and approval.
- `AGENTS.md`, `docs/DEVELOPMENT.md`, `.agents/skills/delivery-workflow/SKILL.md` — keep one canonical command contract.

**Out of scope**:

- Rewriting `build_and_run.sh` behavior.
- Changing local signing identity, TCC behavior, Video-module policy, or log predicates.
- Application source, tests, CI, release workflows, or Git integration.

## Git workflow

- Branch: `advisor/050-consolidate-local-launch-script` or the active isolated implementation branch.
- Commit message: `refactor: consolidate local launch command`.
- Merge and push remain mandatory after executor and review gates.

## Steps

### Step 1: Confirm compatibility surface

Search the repository and the documented development flow for `launch.sh`. Compare its options and behavior with the canonical `build_and_run.sh`. If an external caller is discovered in tracked content, record the caller and stop before changing the interface.

**Verify**: `rg -n "launch\.sh|scripts/launch" README.md AGENTS.md docs .agents scripts --glob '!scripts/launch.sh'` → output is empty or consists only of an explicitly preserved compatibility reference.

### Step 2: Replace duplicate implementation with a wrapper

Prefer replacing the body of `scripts/launch.sh` with a small `set -euo pipefail` wrapper that resolves its own directory and executes `build_and_run.sh --logs "$@"`. Preserve argument forwarding, exit status, and help behavior. Do not duplicate predicates, Xcode settings, process-kill logic, or path discovery.

If the operator explicitly chooses removal after Step 1, delete the file and update all tracked documentation. Do not silently choose deletion merely because no repository caller was found.

**Verify**: `bash -n scripts/launch.sh && ./scripts/launch.sh --help` → exit 0; output comes from the canonical command and no independent `xcodebuild`, `pkill`, or `log stream` implementation remains in the wrapper.

### Step 3: Synchronize the command documentation

Keep `build_and_run.sh` as the only primary command in `AGENTS.md`, `docs/DEVELOPMENT.md`, and `delivery-workflow`. If the compatibility wrapper is retained, document it as legacy convenience only and point to the canonical command for all options.

**Verify**: `rg -n "build_and_run|launch\.sh|canonical|compatib" AGENTS.md docs/DEVELOPMENT.md .agents/skills/delivery-workflow/SKILL.md scripts/launch.sh` → the canonical ownership is unambiguous.

### Step 4: Run local shell and app-path gates

Run shell syntax and help checks. Because a shell entry point changed, run `./scripts/build_and_run.sh --no-video-module --verify` on a configured macOS host; this must use the existing local signing identity and leave the app process verification result visible. If the signing identity, Screen Recording permission, or WindowServer environment is unavailable, stop and report the exact gate instead of weakening the command.

**Verify**: `bash -n scripts/*.sh && git diff --check` → exit 0; the canonical verify mode either confirms the process or reports a documented environment blocker.

## Test plan

- Shell syntax for both scripts.
- Help output through both canonical and compatibility paths.
- Repository reference search.
- One local `--verify` smoke using the canonical script; no Video module is required.

## Done criteria

- [ ] There is one implementation of build/launch/log behavior.
- [ ] `scripts/launch.sh` is either a documented compatibility wrapper or explicitly removed with all callers handled.
- [ ] No duplicate `xcodebuild`, process discovery, or log-stream logic remains in `launch.sh`.
- [ ] Documentation identifies `build_and_run.sh` as canonical.
- [ ] Shell syntax, help, reference search, and local verify gates pass or report an environment blocker.
- [ ] `plans/README.md` status row for 050 is updated.

## STOP conditions

- An untracked or external caller depends on launch-specific behavior that cannot be represented by the canonical command.
- The wrapper would need to change build, signing, Video-module, or log semantics.
- The local verify gate requires changing permissions or deleting the installed app.

## Maintenance notes

New local launch features belong in `build_and_run.sh`. Keep `launch.sh` deliberately boring if retained. Reviewers should reject any future second implementation of Xcode build, bundle-path discovery, process cleanup, or log predicates.
