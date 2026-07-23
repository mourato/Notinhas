# Plan 047: Add a local preflight command for implementation plans

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat d4c52d12..HEAD -- scripts/plan-preflight.sh scripts/tests/plan-preflight.sh .agents/skills/plan-execute-review/SKILL.md AGENTS.md docs/DEVELOPMENT.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `d4c52d12`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: no — this establishes the evidence contract used by later local verification plans.
- **Reviewer required**: yes — shell parsing and Git safety need an independent scope review.
- **Rationale**: The behavior is deterministic and confined to a new read-only/preflight shell command plus documentation, but it interprets Git and Markdown state.
- **Escalate when**: the command must mutate branches, merge, push, or parse legacy plans without an explicit fallback contract.

## Why this matters

The current plan workflow asks an orchestrator to inspect planned commit drift, dependency status, scope, and required gates manually before dispatching an executor. Those checks are mechanical and repeated for every plan, while judgment is still needed for code behavior and manual WindowServer/TCC gates. A local preflight command should fail early with a concise, machine-readable report so an agent does not spend model context rediscovering repository state.

Merge and push remain mandatory project policy; this plan does not change that policy and does not perform either operation.

## Current state

- `plans/README.md` is the project index. It records status, priority, effort, and dependencies in Markdown tables; plan 046 is currently `IN PROGRESS`.
- `plans/046-*.md` and the other existing plans use a `Planned at` SHA, `Depends on`, and `Scope` section, but there is no command that validates those fields before execution.
- `.agents/skills/plan-execute-review/SKILL.md:50-62` requires an orchestrator to check drift, dependencies, and plan text manually. Lines 90–96 require the full plan to be passed to the executor.
- `.agents/skills/plan-execute-review/SKILL.md:78-82` requires the executor/orchestrator to commit, merge, clean up, push, and run the review loop. These actions remain outside this plan.
- `AGENTS.md:41-58` documents local build/test commands and permission-sensitive manual gates. The project uses Bash scripts with `set -euo pipefail`, `bash -n` for syntax validation, and Conventional Commit messages.

The new command must support the current plan format without requiring all historical plans to be rewritten. It may require an explicit `--scope` argument for drift checking because Markdown scope extraction is not reliable enough to mutate or infer silently.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Shell syntax | `bash -n scripts/plan-preflight.sh scripts/tests/plan-preflight.sh` | exit 0 |
| Help contract | `./scripts/plan-preflight.sh --help` | usage includes plan path, dependency check, drift check, scope, report format, and no mutation guarantee |
| Self-test | `scripts/tests/plan-preflight.sh` | all fixture cases pass; no tracked files change |
| Repository hygiene | `git diff --check` | no whitespace errors |

## Suggested executor toolkit

- Read `scripts/run-tests.sh` for repository command style, result paths, and error reporting.
- Follow `project-standards` for command-surface synchronization and `delivery-workflow` for local verification documentation.

## Scope

**In scope** (the only files to modify):

- `scripts/plan-preflight.sh` — new local preflight command.
- `scripts/tests/plan-preflight.sh` — deterministic shell fixture tests.
- `.agents/skills/plan-execute-review/SKILL.md` — document the command as the first local preflight step without weakening merge/push/review requirements.
- `AGENTS.md` — add the command to the local operational command list.
- `docs/DEVELOPMENT.md` — document invocation and report location.

**Out of scope**:

- `plans/README.md` status handling beyond the executor updating the 047 row.
- Any implementation source under `Notinhas/` or `NotinhasTests/`.
- Automatic commit, merge, branch deletion, worktree deletion, or push.
- Reformatting or rewriting historical plans.
- CI workflow changes.

## Git workflow

- Branch: `advisor/047-local-plan-preflight` or the active isolated implementation branch.
- Commit message: `feat: add local plan preflight`.
- Merge and push are mandatory under the project workflow, but must occur only after the executor and reviewer gates required by `plan-execute-review`.

## Steps

### Step 1: Define the command contract and safe failure behavior

Create `scripts/plan-preflight.sh` with `set -euo pipefail`. It must accept a plan path and repeated `--scope PATH` arguments, plus `--report PATH` and `--json`. The default must be read-only: inspect `git rev-parse`, `git status --short`, the plan's `Planned at` SHA, the `Depends on` field, and the status table in `plans/README.md`; do not alter Git state or tracked files.

The command must check:

1. The plan exists and contains a single short SHA in `Planned at`.
2. Every dependency is present in `plans/README.md` and has status `DONE`.
3. Every supplied scope path exists or is explicitly marked as a planned new file.
4. `git diff --stat <planned-sha>..HEAD -- <scope...>` is empty, or the command exits with a drift failure.
5. The worktree has no unrelated changes unless `--allow-dirty` is explicitly supplied; even then, the report must list them.

The command must return non-zero for invalid plans, unresolved dependencies, drift, missing scope paths, or unsafe Git state. It must never infer that a failed check is acceptable.

**Verify**: `bash -n scripts/plan-preflight.sh && ./scripts/plan-preflight.sh --help` → exit 0 and documented options are printed.

### Step 2: Emit stable text and JSON evidence

Add a text report suitable for a human and a JSON report suitable for a later orchestrator. The JSON must contain at least `plan`, `plannedAt`, `currentHead`, `dependencies`, `scope`, `worktreeClean`, `drifted`, `checks`, and `result`. Do not include environment secrets, full prompts, transcripts, or file contents.

When `--report` is omitted, do not create a tracked file. When it is supplied, create parent directories and write only the requested report. Keep generated reports under ignored `build/` by default in documentation examples.

**Verify**: `./scripts/plan-preflight.sh plans/047-local-plan-preflight.md --scope scripts/plan-preflight.sh --scope scripts/tests/plan-preflight.sh --report build/plan-preflight/047.json --json` → expected failure before the new files exist must identify only the missing planned files; after the implementation is complete it exits 0 and `python3 -m json.tool build/plan-preflight/047.json` parses the report.

### Step 3: Add fixture tests for pass and fail paths

Implement `scripts/tests/plan-preflight.sh` using temporary directories and a temporary Git repository or stubs that do not touch the project's Git state. Cover: valid plan, missing plan, malformed SHA, unresolved dependency, drifted scope, dirty worktree, `--allow-dirty`, text output, JSON output, and a planned new file. Assert exit status and stable error labels rather than incidental wording.

**Verify**: `scripts/tests/plan-preflight.sh` → all fixture cases pass and `git status --short` shows no tracked changes outside the plan's in-scope files.

### Step 4: Route agents and documentation through the command

Update `plan-execute-review` so preflight is the first local action, before dispatch or implementation. Keep the existing isolated worktree, commit, merge, cleanup, push, and thermo-review requirements unchanged. Update `AGENTS.md` and `docs/DEVELOPMENT.md` with one canonical example and explain that a clean preflight does not replace code review or manual capture/TCC/WindowServer gates.

**Verify**: `rg -n "plan-preflight|merge|push|thermo|manual" .agents/skills/plan-execute-review/SKILL.md AGENTS.md docs/DEVELOPMENT.md` → shows the new command and the unchanged mandatory Git/review policy; no CI files are modified.

## Test plan

- Shell fixtures in `scripts/tests/plan-preflight.sh` cover every deterministic check listed in Step 3.
- Run `bash -n` on both scripts and `git diff --check`.
- Run the command against this plan with explicit scopes and a JSON report.
- Do not run the app build merely for this read-only preflight feature; if documentation changes trigger the project’s normal delivery gate, run the relevant filtered XCTest command and report the result.

## Done criteria

- [ ] `scripts/plan-preflight.sh --help` exits 0.
- [ ] The fixture test exits 0 and covers both successful and failing preflight states.
- [ ] A valid plan with explicit scopes produces stable text and JSON evidence.
- [ ] Drift, unresolved dependencies, missing paths, and unsafe dirty state fail closed.
- [ ] The command does not mutate Git state, tracked files, branches, worktrees, or remotes.
- [ ] Documentation keeps merge, cleanup, push, and review mandatory.
- [ ] `bash -n` and `git diff --check` exit 0.
- [ ] `plans/README.md` status row for 047 is updated.

## STOP conditions

- The existing plan format cannot expose dependency or planned-SHA data without rewriting historical plans.
- Safe detection of a planned new file requires inferring scope from prose rather than an explicit argument.
- The implementation proposes automatically changing Git state or pushing.
- A fixture would need to execute against the real project’s branch, worktree, remote, or secrets.

## Maintenance notes

Future plans should include explicit `--scope` paths in their executor instructions so drift checks remain machine-checkable. If the plan format gains front matter or a structured metadata block, extend this command to consume that format while preserving the current explicit-argument fallback. Reviewers should verify that reports contain metadata and statuses only, never prompts, credentials, or machine state.
