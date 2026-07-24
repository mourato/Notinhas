# Plan 076: Retarget Code of Conduct and uninstall branding leftovers

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat a6128271..HEAD -- CODE_OF_CONDUCT.md uninstall.sh`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `a6128271`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes`
- **Reviewer required**: `no`
- **Rationale**: Branding string fixes only; keep CoC structure.
- **Escalate when**: Maintainer wants to delete CoC entirely instead of retargeting.

## Why this matters

`CODE_OF_CONDUCT.md` still says “Snapzy community” / “Snapzy project”. `uninstall.sh` footer points reinstall at `duongductrong/Notinhas` and still has a Sparkle cleanup section for an updater Notinhas does not ship. That confuses users and agents.

## Current state

```5:5:CODE_OF_CONDUCT.md
We as members, contributors, and maintainers pledge to make participation in the Snapzy community a harassment-free experience for everyone, ...
```

```35:35:CODE_OF_CONDUCT.md
... representing the Snapzy project in public spaces.
```

`uninstall.sh`:
- Sparkle section ~222–234 (`Removing Sparkle update data…`)
- Footer URL `https://github.com/duongductrong/Notinhas/releases`
- Header may claim `./scripts/uninstall.sh` while file lives at repo root — fix comment to `./uninstall.sh` if wrong
- Temp path `/tmp/test-tcc-snapzy` can stay as migration cleanup **or** add `/tmp/test-tcc-notinhas` — prefer keep snapzy temp cleanup for old installs AND ensure notinhas temp is cleaned if present

**Keep** `install.sh` / `uninstall.sh` as distribution helpers (DMG curl path); do not delete them in this plan.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| CoC clean | `rg -n 'Snapzy' CODE_OF_CONDUCT.md` | no matches |
| Uninstall org | `rg -n 'duongductrong' uninstall.sh` | no matches |
| Uninstall Sparkle section | `rg -n 'Sparkle' uninstall.sh` | no matches (or only a one-line comment that Sparkle is not used — prefer no section) |

## Scope

**In scope**:
- `CODE_OF_CONDUCT.md` — replace Snapzy → Notinhas (community/project wording)
- `uninstall.sh` — fix reinstall URL to `https://github.com/mourato/Notinhas/releases`; remove Sparkle cleanup section (or reduce to no-op comment); fix incorrect script path in header comments; ensure temp cleanup includes Notinhas debug paths if missing

**Out of scope**:
- Deleting install/uninstall scripts
- Rewriting entire CoC enforcement policy
- CHANGELOG (plan 077)

## Git workflow

- Branch: `advisor/076-retarget-coc-uninstall-branding`
- Commit: `docs: retarget Code of Conduct and uninstall branding to Notinhas`
- Do NOT push unless instructed.

## Steps

### Step 1: Retarget CoC

Replace “Snapzy community” → “Notinhas community” and “Snapzy project” → “Notinhas project”. Do not change Contributor Covenant structure.

**Verify**: `rg -n 'Snapzy' CODE_OF_CONDUCT.md` → no matches

### Step 2: Fix uninstall.sh branding and Sparkle section

- Footer URL → `mourato/Notinhas`
- Delete section “Remove Sparkle update data” and related `defaults delete …Sparkle`
- Fix header usage comments to match actual path (`./uninstall.sh` / curl raw URL for mourato)
- Keep legacy Snapzy Application Support cleanup if present (migration hygiene)

**Verify**: Commands table checks pass; `bash -n uninstall.sh` → exit 0

## Test plan

- `bash -n uninstall.sh` and `bash -n install.sh` (install untouched but sanity)

## Done criteria

- [ ] CoC has no “Snapzy”
- [ ] uninstall footer uses mourato/Notinhas
- [ ] No Sparkle cleanup block in uninstall.sh
- [ ] `bash -n uninstall.sh` exits 0
- [ ] install.sh not deleted

## STOP conditions

- Maintainer wants CoC removed entirely — STOP and ask.
- uninstall.sh structure differs enough that section numbers don’t match — adapt carefully but don’t delete unrelated wipe logic.

## Maintenance notes

- install.sh remains the curl convenience path alongside DMG (documented keep in plan 078).
- Reviewers: do not remove TCC reset behavior while cleaning Sparkle.
