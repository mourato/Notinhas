# Plan 054: Adopt global macOS skills with Notinhas overlays

> **Executor instructions**: This is a guidance-only migration. Do not modify
> Swift, Xcode, scripts, product documentation, or runtime configuration. The
> global prerequisite must already be merged before executing this plan.
>
> **Drift check (run first)**: `git diff --stat 1b0c9da4..HEAD -- AGENTS.md .agents/skills .agents/overlays plans/README.md`

## Status

- **Status**: DONE — merged to `main` as `6b35981e` via PR #1.
- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: global Plan 004 (`/Users/usuario/.agents/plans/004-globalize-macos-skills-and-overlay-contract.md`) merged to `/Users/usuario/.agents` `main`; this dependency must be checked in that global checkout, not inferred from any historical Notinhas-local Plan 004.
- **Category**: migration / dx / docs
- **Planned at**: commit `1b0c9da4`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — serialize product migrations after the global merge
- **Reviewer required**: yes — deleting local skill copies changes routing
- **Rationale**: The change is guidance-only but affects all future agent sessions and Notinhas-specific routing.
- **Escalate when**: any product source, script, test, or upstream fork file must change, or the global skill is unavailable to the active harness.

## Why this matters

Notinhas carries local copies of seven cross-project skills plus two skills that
must remain product-specific. Moving the shared rules to the canonical global
checkout removes drift while preserving the visual-handoff workflow and fork
constraints in local overlays.

## Current state

- `AGENTS.md:31-39` says project skills live under `.agents/skills/` and names
  `project-standards` and `capture-annotate-export` as local owners.
- The seven shared local copies are under
  `.agents/skills/{accessibility-audit,apple-design,code-quality,delivery-workflow,macos-app-engineering,menubar,swift-conventions}/`.
- `capture-annotate-export`, `plan-execute-review`, and `project-standards`
  remain Notinhas-specific and must not be removed.
- The canonical validation commands are
  `./scripts/run-tests.sh`, `./scripts/verify-local.sh`, and the plan preflight.
  Plan preflight is a pre-implementation drift/dependency/scope check; after
  edits, use the committed-scope audit and structural checks. This guidance-only
  change must not claim product tests were run if no source changed.

## Scope

**In scope**

- `AGENTS.md`
- `scripts/verification-map.tsv` — one docs/manual-review mapping row for
  `.agents/overlays/**`, so `verify-local.sh` classifies the new companions like
  existing skill guidance instead of treating them as an unmapped surface.
- `.agents/overlays/` with seven Notinhas overlay files
- `.agents/skills/project-standards/SKILL.md`
- `.agents/skills/capture-annotate-export/SKILL.md` and
  `.agents/skills/plan-execute-review/SKILL.md`, only to replace broken
  relative references to migrated global skills
- Delete only the seven duplicate local skill directories listed above
- `plans/README.md` and this plan

**Out of scope**

- `Notinhas/**`, `NotinhasTests/**`, scripts other than the single
  `scripts/verification-map.tsv` row, Xcode files, release files, upstream
  remotes, and product behavior
- `capture-annotate-export`, `plan-execute-review`, `project-standards`, and
  any other local specialist skill
- Any global skill content; that belongs to the global plan

## Overlay contents

Each overlay must use the documented companion format and contain only:

- Notinhas product intent: capture → annotate → clipboard-ready handoff;
- `Notinhas/` and `NotinhasTests/` canonical paths;
- Screen Recording and Accessibility permission gates;
- `./scripts/build_and_run.sh`, `./scripts/run-tests.sh`, and
  `./scripts/verify-local.sh` command mapping;
- optional Video-module behavior and the manual capture/annotate/export gate;
- Notinhas branding/fork constraints and the rule not to reintroduce Sparkle,
  support endpoints, or unrelated recording/cloud features.

Do not copy generic Swift, delivery, accessibility, menu-bar, or Apple-design
rules into the overlays.

## Steps

### Step 1: Confirm prerequisite and clean integration base

Before editing, run the plan preflight against the clean integration base and
confirm the dependency directly in the global checkout. The global Plan 004
dependency cannot be inferred from a Notinhas-local Plan 004 with the same
number; verify `/Users/usuario/.agents` `main` and the seven global skill paths
there. Create an explicit branch:

```sh
git switch main
git pull --ff-only origin main
git switch -c chore/notinhas-global-skill-overlays
./scripts/plan-preflight.sh plans/054-adopt-global-macos-skill-overlays.md --scope .agents --scope AGENTS.md --scope scripts/verification-map.tsv
git -C /Users/usuario/.agents status --short --branch
git -C /Users/usuario/.agents merge-base --is-ancestor e885e11 main
```

**Verify**: `git status --short --branch` → clean feature branch; the global
Plan 004 commit is an ancestor of the global checkout's `main`; the global
skill paths resolve and are not local same-name copies. This is the required
pre-edit plan-preflight invocation; do not treat a dirty post-edit worktree as
a preflight pass.

### Step 2: Add Notinhas overlays and routing

Create the seven files under `.agents/overlays/`. Update `AGENTS.md` so global
skills are referenced as global capabilities and each matching overlay is
loaded with the global skill. Keep `project-standards` as the local owner of
guidance governance.

Update only stale cross-links in retained local skills. A reference to a
migrated global skill must use its global name, not a relative local path.

**Verify**: `rg -n "global:|project-overlay|\.agents/overlays|capture-annotate-export|project-standards" AGENTS.md .agents/skills .agents/overlays` → routing is explicit and no migrated local path is referenced.

### Step 3: Remove duplicate local copies

After routing is correct, delete only the seven local duplicate directories.
Before deletion, confirm their `SKILL.md` names match the global names and that
no retained local skill depends on their private references. Do not delete
specialist Notinhas skills.

**Verify**: `find .agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort` → only local specialists remain; `find .agents/overlays -name '*.md' | wc -l` → 7.

### Step 4: Validate and review

After implementation, run:

```sh
git diff --check
./scripts/verify-local.sh --base main --plan-only --strict
git diff --name-status main...HEAD
find .agents/overlays -maxdepth 1 -type f -name '*.md' -print | sort
find .agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md -print | sort
```

Expected result: no whitespace errors; the changed-surface report classifies
the change as guidance-only; the committed-scope audit lists only the approved
guidance and plan paths; seven overlays exist, the seven duplicate global skill
copies do not, and retained specialist skills remain. Plan preflight is not a
post-change gate.
Do not run the full XCTest suite unless the changed-surface tool reports a
product path or the reviewer requests it.

### Step 5: Commit, push, merge, and clean up

Stage only `AGENTS.md`, `.agents/`, the single validation-map row, and the plan files. Because this repository
ignores `/plans`, force-add only this plan document if the team has decided to
version the plan itself:

```sh
git add AGENTS.md .agents/ scripts/verification-map.tsv plans/README.md
git add -f plans/054-adopt-global-macos-skill-overlays.md
git diff --cached --check
```

Commit:

```text
docs(agents): adopt global macos skill overlays
```

Push the feature branch, open a PR against `main`, wait for review and required
checks, then merge through the repository's normal protected-branch path. After
verifying the PR is merged and `origin/main` contains the commit:

```sh
git switch main
git pull --ff-only origin main
git fetch origin --prune
git branch -d chore/notinhas-global-skill-overlays
git push origin --delete chore/notinhas-global-skill-overlays  # only if still present
git worktree list
```

Remove only the disposable worktree created for this branch. Never delete
`main`, `upstream`, or an unmerged branch.

## Test plan

- Confirm seven overlays exist and each declares the corresponding global
  skill.
- Confirm no duplicate local `SKILL.md` exists for the seven global names.
- Confirm retained Notinhas skills have no broken relative links.
- Run `./scripts/verify-local.sh --base main --plan-only --strict`.
- Record the pre-edit plan preflight and global prerequisite checks; do not
  report plan preflight as a post-change validation.
- Audit the committed scope with `git diff --name-status main...HEAD` and the
  structural overlay/no-duplicate/reference checks.
- Manually inspect that capture/annotate/export guidance remains local and that
  Video-module and TCC constraints were not moved into global skills.

## Done criteria

- [ ] Seven Notinhas overlays exist under `.agents/overlays/`.
- [ ] `AGENTS.md` explicitly routes global skill plus overlay.
- [ ] Seven duplicate local skill directories are removed; specialists remain.
- [ ] Pre-edit plan preflight and global prerequisite checks are recorded;
      post-change guidance checks and committed-scope audit pass.
- [ ] No product source, runtime script, Xcode, or configuration files changed;
      only the approved `scripts/verification-map.tsv` validation row changed.
- [ ] Commit, PR push, merge, local cleanup, remote branch cleanup, and worktree
      cleanup are complete and recorded.
- [ ] `plans/README.md` marks Plan 054 according to the repository convention.

## STOP conditions

- The global prerequisite is not merged or is not discoverable.
- The working tree has unrelated changes.
- A retained local skill requires private reference files from a deleted copy.
- The validator reports a source/runtime path changed.
- A merge conflict would require changing product source or upstream fork code.

## Maintenance notes

Future Notinhas-specific rules belong in overlays or `capture-annotate-export`,
not in the global skills. Review overlays whenever `AGENTS.md`, build scripts,
permissions, or the optional Video module changes.
