# Plan 049: Automate the mandatory local Git integration protocol

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat d4c52d12..HEAD -- scripts/integrate-plan.sh scripts/tests/integrate-plan.sh .agents/skills/plan-execute-review/SKILL.md plans/README.md docs/DEVELOPMENT.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: plans/047-local-plan-preflight.md, plans/048-local-changed-surface-verification.md
- **Category**: dx
- **Planned at**: commit `d4c52d12`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — it formalizes the integration contract after preflight and verification evidence exist.
- **Reviewer required**: yes — the command can merge, push, and clean up Git state.
- **Rationale**: The sequence is deterministic but externally mutating. Explicit dry-run, target validation, and failure stops reduce risk without weakening mandatory versioning discipline.
- **Escalate when**: force-push, automatic conflict resolution, unreviewed merges, deletion of an unexpected branch/worktree, or remote selection beyond an explicit argument is proposed.

## Why this matters

The project deliberately requires `commit → merge → cleanup → push`, followed by integrated review and remediation. That discipline must remain. The opportunity is to make the protocol reproducible and fail closed so an agent does not improvise branch names, target refs, cleanup order, or push commands in every plan.

The command must be dry-run by default and require an explicit apply flag for every state-changing operation. It must never bypass the plan preflight, verification evidence, or thermo-nuclear review requirements.

## Current state

- `.agents/skills/plan-execute-review/SKILL.md:33-43` defines the executor/reviewer contract.
- `.agents/skills/plan-execute-review/SKILL.md:78-82` requires commit, merge, cleanup, push, and post-integration review.
- `plans/README.md:69-86` duplicates that policy and states that no executor may silently skip a gate or widen scope.
- Git conventions in `AGENTS.md:84-93` require `upstream` awareness, focused commits, Conventional Commit messages, validation notes, and preservation of unrelated changes.
- The repository has `origin` as `mourato/Notinhas`, `upstream` as `duongductrong/Snapzy`, and `main` as the integration branch.

The new command is a protocol runner, not a merge strategy. It may use only normal `git merge --no-ff`, explicit remote/ref arguments, and ordinary push. Conflicts, dirty state, missing review evidence, or unexpected branch/worktree state must stop.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Syntax | `bash -n scripts/integrate-plan.sh scripts/tests/integrate-plan.sh` | exit 0 |
| Help | `./scripts/integrate-plan.sh --help` | documents dry-run default, explicit apply, target/source/ref arguments, cleanup, and no-force-push policy |
| Safe preview | `./scripts/integrate-plan.sh --dry-run --source-branch advisor/example --target-branch main --remote origin` | prints planned checks/commands without changing Git state |
| Fixture integration | `scripts/tests/integrate-plan.sh` | temporary-repository apply and failure cases pass |
| Hygiene | `git diff --check` | no whitespace errors |

## Scope

**In scope**:

- `scripts/integrate-plan.sh` — explicit local integration protocol.
- `scripts/tests/integrate-plan.sh` — temporary-repository tests.
- `.agents/skills/plan-execute-review/SKILL.md` — route the integration section through the command.
- `plans/README.md` — document that the protocol remains mandatory and record the command.
- `docs/DEVELOPMENT.md` — local Git workflow reference.

**Out of scope**:

- Changing whether commits, merges, cleanup, pushes, or thermo review are mandatory.
- Force-pushing, rebasing shared branches, automatic conflict resolution, or deleting arbitrary branches.
- GitHub Actions, pull-request creation, or remote issue publication.
- Application source, tests, or release artifacts.

## Git workflow

- Branch: `advisor/049-local-git-integration-protocol` or the active isolated implementation branch.
- Commit message: `chore: automate local git integration protocol`.
- The plan itself must be committed, merged, reviewed, and pushed using the project’s existing mandatory workflow.

## Steps

### Step 1: Define dry-run and safety checks

Create `scripts/integrate-plan.sh` with `set -euo pipefail`. Require explicit `--source-branch`, `--target-branch`, and `--remote`; default to `--dry-run`. Add `--apply`, `--evidence PATH`, `--reviewed-commit SHA`, and separate `--cleanup` flags. Under `--apply`, require an evidence report and a reviewed commit matching the source commit; the script verifies their presence and identity but does not attempt to judge review quality. Before showing or applying operations, verify:

- the current worktree is the intended integration worktree and is clean;
- source and target refs resolve on the named remote/local repository;
- source and target are not the same ref;
- no merge is already in progress;
- the source commit has a successful preflight/verification/review evidence path supplied through explicit arguments or a report file;
- no force-push or implicit remote is being used.

Use stable labels such as `CHECK`, `PLAN`, `APPLY`, `STOP`, and `RESULT`. Do not print credentials or full environment state.

**Verify**: `bash -n scripts/integrate-plan.sh && ./scripts/integrate-plan.sh --help` → exit 0; help states that default mode is non-mutating.

### Step 2: Implement the guarded integration sequence

Under `--apply`, perform only this sequence:

1. fetch the explicitly named remote ref if requested by an explicit flag;
2. verify the source commit and required evidence again;
3. switch to the exact target branch only if the target worktree is the one named by the operator;
4. run `git merge --no-ff <source>`;
5. stop on conflicts or any non-zero result;
6. push the exact target branch to the exact remote without `--force`;
7. run cleanup only when `--cleanup` is explicit and the source worktree/branch identity matches the recorded source.

Do not mark a plan `DONE` automatically. The reviewer must confirm the integrated diff and update `plans/README.md` after all findings are resolved.

**Verify**: a temporary Git repository with a source branch and target branch completes `--apply --cleanup` only when explicitly requested; the real project remains on its original branch and has no remote mutation during this test.

### Step 3: Add failure and no-side-effect tests

Implement `scripts/tests/integrate-plan.sh` using temporary repositories. Cover dry-run, dirty worktree, same source/target, missing ref, merge conflict, failed push using a local bare remote, omitted `--apply`, and cleanup without matching branch identity. Assert that no force-push appears in generated commands and that failed operations stop without deleting unrelated refs.

**Verify**: `scripts/tests/integrate-plan.sh` → all cases pass; `git status --short` in the project remains unchanged.

### Step 4: Route the skill and documentation through the protocol

Update `plan-execute-review` and `plans/README.md` to say that the script standardizes the existing mandatory sequence. Keep the explicit requirement for isolated worktree execution, commit, merge, cleanup, push, integrated thermo review, and fixing every finding. Document that dry-run is safe for inspection and `--apply` is required for mutation.

**Verify**: `rg -n "integrate-plan|commit|merge|cleanup|push|force|thermo" .agents/skills/plan-execute-review/SKILL.md plans/README.md docs/DEVELOPMENT.md` → all mandatory stages remain represented and no CI file is changed.

## Test plan

- Temporary local Git repositories cover the full protocol and failure stops.
- `bash -n` and `git diff --check` pass.
- Run only the dry-run command against the project during development; do not apply it to the user’s actual branch until the reviewer authorizes the exact refs.
- The normal plan-execute-review integration and push gates remain required for delivery.

## Done criteria

- [ ] Dry-run is the default and has no Git side effects.
- [ ] Apply mode requires explicit source, target, remote, and `--apply`.
- [ ] The sequence preserves commit, merge, cleanup, push, and post-integration review.
- [ ] Conflicts, dirty state, missing refs, failed pushes, and evidence gaps stop safely.
- [ ] No force-push or automatic conflict resolution exists.
- [ ] Temporary-repository tests pass.
- [ ] No CI or application files are modified.
- [ ] `plans/README.md` status row for 049 is updated.

## STOP conditions

- Git worktree topology makes it impossible to identify the exact target worktree safely.
- The implementation needs force-push, rebase, automatic conflict resolution, or broad branch deletion.
- Evidence cannot distinguish a reviewed integrated commit from an unreviewed source commit.
- A test requires applying the protocol to the real `origin` remote.

## Maintenance notes

Keep the command intentionally conservative. Changes to branch naming, integration branch, remote ownership, or worktree orchestration require updating both the script and `AGENTS.md`. The reviewer should inspect the generated Git commands and verify that cleanup occurs only after a successful push and only for the recorded source branch/worktree.
