# Plan 054: Adopt global macOS skills with Notinhas overlays

> **Executor instructions**: This is a guidance-only migration. Do not modify
> Swift, Xcode, scripts, product documentation, or runtime configuration. The
> global prerequisite must already be merged before executing this plan.
>
> **Drift check (run first)**: `git diff --stat 1b0c9da4..HEAD -- AGENTS.md .agents/skills .agents/overlays plans/README.md`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: global plan `/Users/usuario/.agents/plans/004-globalize-macos-skills-and-overlay-contract.md` merged to global `main`
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
  `./scripts/run-tests.sh`, `./scripts/verify-local.sh`, and the plan preflight;
  this guidance-only change must not claim product tests were run if no source
  changed.

## Scope

**In scope**

- `AGENTS.md`
- `.agents/overlays/` with seven Notinhas overlay files
- `.agents/skills/project-standards/SKILL.md`
- `.agents/skills/capture-annotate-export/SKILL.md` and
  `.agents/skills/plan-execute-review/SKILL.md`, only to replace broken
  relative references to migrated global skills
- Delete only the seven duplicate local skill directories listed above
- `plans/README.md` and this plan

**Out of scope**

- `Notinhas/**`, `NotinhasTests/**`, `scripts/**`, Xcode files, release files,
  upstream remotes, and product behavior
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

Confirm the global seven skills are discoverable through the active harness and
that the working tree is clean. Create an explicit branch:

```sh
git switch main
git pull --ff-only origin main
git switch -c chore/notinhas-global-skill-overlays
```

**Verify**: `git status --short --branch` → clean feature branch; the global
skill paths resolve and are not local same-name copies.

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

Run:

```sh
git diff --check
./scripts/verify-local.sh --base main --plan-only --strict
./scripts/plan-preflight.sh plans/054-adopt-global-macos-skill-overlays.md --scope .agents --scope AGENTS.md
```

Expected result: no whitespace errors; the changed-surface report classifies
the change as guidance-only; plan preflight reports no drift or scope error.
Do not run the full XCTest suite unless the changed-surface tool reports a
product path or the reviewer requests it.

### Step 5: Commit, push, merge, and clean up

Stage only `AGENTS.md`, `.agents/`, and the plan files. Because this repository
ignores `/plans`, force-add only this plan document if the team has decided to
version the plan itself:

```sh
git add AGENTS.md .agents/ plans/README.md
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
- Manually inspect that capture/annotate/export guidance remains local and that
  Video-module and TCC constraints were not moved into global skills.

## Done criteria

- [ ] Seven Notinhas overlays exist under `.agents/overlays/`.
- [ ] `AGENTS.md` explicitly routes global skill plus overlay.
- [ ] Seven duplicate local skill directories are removed; specialists remain.
- [ ] Guidance checks and plan preflight pass.
- [ ] No product source or scripts changed.
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
