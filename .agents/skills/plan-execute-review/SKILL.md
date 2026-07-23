---
name: plan-execute-review
description: >-
  Orchestrator loop for improve-skill plans — dispatch an implementer subagent,
  integrate via commit/merge/cleanup/push, then thermo-nuclear review and fix
  every finding before the next plan. Use when executing plans/, running the
  advisor→executor→reviewer pipeline, or when the user asks to implement a plan
  with Composer 2.5 / GPT 5.6 Medium and full integration.
---

# Plan → Execute → Review

## Role

Canonical owner of the **orchestrator / executor / reviewer** loop for Notinhas
handoff plans under `plans/`. Complements `/improve` (plan authoring) and
`/thermo-nuclear-code-quality-review` (post-integration audit).

## Scope Boundary

- Owns: dispatch model choice, executor git integration (commit → merge →
  cleanup → push), thermo review trigger, finding remediation gate, and
  sequential plan advancement.
- Does **not** author new improve findings (that is `/improve`).
- Does **not** replace `delivery-workflow` command tables — reuse them inside
  plan gates and review fixes.

## When to Use

- User asks to execute one or more `plans/NNN-*.md` files end-to-end.
- User asks for the “Composer executor + thermo review” pipeline.
- After `/improve` writes plans and the maintainer selects which to ship.

## Model contract

| Host | Implementer subagent model |
|------|----------------------------|
| Cursor | **Composer 2.5** (`composer-2.5`) |
| Codex | **GPT 5.6 Medium** (or the host’s equivalent medium implementer) |

If neither model is available in the current host, **stop and ask the user**
which model to use for the executor. Do not silently substitute a different
model unless the user explicitly requests one.

The **orchestrator** (this session’s primary agent) stays on the host’s primary
model and owns review + finding fixes.

## Hard rules

1. The orchestrator creates a **subagent** to implement each plan. The
   orchestrator does not implement plan source changes itself during the
   execute phase.
2. One plan at a time. Do not start plan N+1 until plan N is integrated,
   thermo-reviewed, and every finding is fixed and committed.
3. Executor works in an **isolated git worktree** (or equivalent isolation).
4. After a successful executor run, the executor (or orchestrator if isolation
   blocked integration) must run the guarded local protocol via
   `./scripts/integrate-plan.sh`: **commit → merge into the integration branch →
   remove worktree/branch cleanup → push**. Default to `--dry-run` for inspection;
   use `--apply` only with explicit refs, evidence, and reviewed commit SHA.
5. After integration, the orchestrator runs
   `/thermo-nuclear-code-quality-review` on the integrated diff.
6. **Every** thermo finding must be treated (fixed or explicitly deferred with
   maintainer approval) and committed before advancing.
7. Never skip plan STOP conditions, widen scope, or leave `plans/README.md`
   stale.

## Loop (per plan)

```
┌─────────────────┐
│ Orchestrator    │  drift-check plan; confirm deps DONE in plans/README.md
└────────┬────────┘
         │ spawn implementer subagent (Composer 2.5 / GPT 5.6 Medium)
         ▼
┌─────────────────┐
│ Executor        │  implement plan in worktree; run every gate
│                 │  integrate-plan.sh (dry-run, then --apply when authorized)
│                 │  commit → merge → cleanup → push
└────────┬────────┘
         │ return STATUS report + SHAs
         ▼
┌─────────────────┐
│ Orchestrator    │  verify done criteria; scope audit; thermo-nuclear review
│                 │  fix ALL findings; commit; push
│                 │  mark plan DONE in plans/README.md
└────────┬────────┘
         │ if more selected plans remain → repeat
         ▼
       done
```

### 1. Orchestrator — preflight

- Run `./scripts/plan-preflight.sh` as the **first local action** before
  dispatch or implementation. Pass the plan path, every in-scope path via
  repeated `--scope` / `--new-file`, and optionally
  `--report build/plan-preflight/<plan>.json --json` for machine-readable
  evidence. The command is read-only and never replaces merge, push, thermo
  review, or manual capture/TCC/WindowServer gates.
- Confirm `plans/README.md` dependencies for this plan are `DONE` (also checked
  by preflight).
- Run the plan’s drift check against `Planned at` (also checked by preflight
  for tracked scope paths).
- If drifted, reconcile the plan before dispatch (do not hand a stale plan).
- Inline the **full plan file text** into the subagent prompt (worktrees may
  not see uncommitted `plans/`).

### 2. Executor — implement

Prompt the subagent to:

- Follow the plan step by step; honor STOP conditions.
- Touch only in-scope files.
- Run every verification command; report evidence.
- Commit with Conventional Commits matching recent `git log`.
- Run `./scripts/plan-preflight.sh` and `./scripts/verify-local.sh` first;
  capture reports under `build/plan-preflight/` and `build/verification/`.
- Preview integration with `./scripts/integrate-plan.sh --dry-run` using
  explicit `--source-branch`, `--target-branch`, and `--remote`.
- When the orchestrator authorizes mutation, run `./scripts/integrate-plan.sh
  --apply --fetch` with `--evidence` (integration manifest or passing reports)
  and `--reviewed-commit` matching the source tip; add `--cleanup` only after a
  successful push and only for the recorded source branch/worktree.
- The script performs merge (`--no-ff`), push (never `--force`), and optional
  cleanup. It does not mark plans `DONE`; thermo review still follows.
- Reply with:

```
STATUS: COMPLETE | STOPPED
STEPS: …
STOPPED BECAUSE: …
FILES CHANGED: …
MERGE_SHA: …
PUSH: yes | no
NOTES: …
```

If the executor cannot merge/push from isolation, it must return the commit SHA
and stop; the orchestrator completes merge, cleanup, and push — then still runs
thermo review.

### 3. Orchestrator — thermo review

- Load `/thermo-nuclear-code-quality-review` and the project review profile.
- Review the integrated diff (merge SHA), not only the executor’s summary.
- Produce findings (Critical / Medium / Low).
- Fix every finding (or get explicit deferral), re-run relevant gates, commit,
  and push.
- Update `plans/README.md` status to `DONE` with merge + review-fix SHAs.

### 4. Advance

Only then start the next selected plan with a **fresh** executor dispatch.

## Relationship to `/improve` execute

`/improve`’s default `execute` variant keeps the advisor read-only and leaves
merge/push to the human. **This skill overrides that for Notinhas** when the
user invokes the plan-execute-review pipeline: integration (merge/push) and
finding remediation are required parts of the loop.

Plan authoring, finding tables, and `plans/` templates remain owned by
`/improve`.

## Related Skills

- `/improve` — survey and write `plans/`
- `/thermo-nuclear-code-quality-review` — post-merge quality bar
- `delivery-workflow` — build/test/format commands
- `project-standards` — skill registry and AGENTS alignment
