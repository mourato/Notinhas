# Plan 071: Retire Discord release-notify workflow

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat a6128271..HEAD -- .github/workflows/release-notify.yml docs/RELEASES.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (can run parallel with 070; serialize same-day merge if both touch `docs/RELEASES.md`)
- **Category**: dx
- **Planned at**: commit `a6128271`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — notify workflow only; coordinate RELEASES.md with 070
- **Reviewer required**: `no`
- **Rationale**: Delete one unused community broadcast workflow + one docs bullet.
- **Escalate when**: Operator confirms `DISCORD_WEBHOOK_URL` is actively used for Notinhas releases.

## Why this matters

Upstream Snapzy used Discord release announcements. Notinhas is a tailored fork with manual GitHub Releases. The `Release Notify` workflow only no-ops without `DISCORD_WEBHOOK_URL`, but docs still advertise it and the workflow remains maintenance surface.

## Current state

- `.github/workflows/release-notify.yml` — triggers on successful `Release Publish` workflow_run; posts Discord embed when secret set.
- `docs/RELEASES.md:47` — “**Release Notify** workflow posts to Discord when `DISCORD_WEBHOOK_URL` is configured.”

Excerpt:

```1:6:.github/workflows/release-notify.yml
name: Release Notify

on:
  workflow_run:
    workflows: ["Release Publish"]
    types: [completed]
```

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Gone | `test ! -f .github/workflows/release-notify.yml` | exit 0 |
| Docs clean | `rg -n 'Discord|release-notify|DISCORD_WEBHOOK' docs/RELEASES.md` | no matches |

## Scope

**In scope**:
- Delete `.github/workflows/release-notify.yml`
- Update `docs/RELEASES.md` — remove Discord / Release Notify bullet; keep GitHub Release steps accurate

**Out of scope**:
- `release-publish.yml` DMG/create-dmg steps
- GitHub Release creation itself
- Adding any other notify channel

## Git workflow

- Branch: `advisor/071-retire-discord-notify`
- Commit: `chore: remove Discord release notify workflow`
- Do NOT push unless instructed.

## Steps

### Step 1: Delete the workflow

Delete `.github/workflows/release-notify.yml`.

**Verify**: `test ! -f .github/workflows/release-notify.yml` → exit 0

### Step 2: Update RELEASES.md

Remove the Discord notify bullet (and any other Discord-only sentences in that file). Ensure the “GitHub Release steps” list still makes sense without renumbering gaps (renumber if needed).

**Verify**: `rg -n 'Discord|DISCORD_WEBHOOK|Release Notify' docs/RELEASES.md` → no matches

### Step 3: Repo sweep

```bash
rg -n 'release-notify|DISCORD_WEBHOOK' README.md docs AGENTS.md .github --glob '!CHANGELOG.md'
```
→ no matches outside `plans/`

## Test plan

- None (workflow/docs). Confirm remaining workflows under `.github/workflows/` still include `release-publish.yml`, `ci.yml`, etc.

## Done criteria

- [ ] `release-notify.yml` deleted
- [ ] `docs/RELEASES.md` no longer documents Discord notify
- [ ] No other in-repo docs (except CHANGELOG history / plans) advertise Discord release notify
- [ ] Scope respected

## STOP conditions

- Maintainer says Discord announce is required — STOP and keep workflow.
- `docs/RELEASES.md` already has no Discord mention and workflow already gone — mark REJECTED/DONE.

## Maintenance notes

- Re-adding Discord requires an explicit product decision; prefer GitHub Releases UI only.
- Secret `DISCORD_WEBHOOK_URL` on the GitHub repo can be deleted by a human in Settings (out of scope for the executor).
