# Plan 077: Re-root CHANGELOG for Notinhas (keep release extract working)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat a6128271..HEAD -- CHANGELOG.md scripts/update-changelog.sh .github/workflows/release-publish.yml docs/`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: docs
- **Planned at**: commit `a6128271`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: `no` — release-publish extracts latest `## [` entry
- **Reviewer required**: `yes` — easy to break release notes extraction
- **Rationale**: Large file + CI awk contract; archive must preserve Keep a Changelog headings.
- **Escalate when**: `update-changelog.sh` / release-publish changelog extract logic differs from excerpts.

## Why this matters

`CHANGELOG.md` (~2595 lines) still says “All notable changes to **Snapzy**” and is dominated by upstream “chore: update appcast…” noise. Release Publish extracts the latest `## [version]` section via awk for the GitHub Release body — any rewrite must keep that contract.

## Current state

Header:

```1:4:CHANGELOG.md
# Changelog

All notable changes to Snapzy will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
```

First version heading appears around line 104: `## [1.30.0-beta.12] - 2026-07-20`.

Release extract (`release-publish.yml`):

```bash
awk '/^## \[/{if(found) exit; found=1; next} found' CHANGELOG.md > build/changelog.md
```

`scripts/update-changelog.sh` prepends a new `## [${VERSION}] - ${DATE}` entry before the first `## [` heading.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Header | `rg -n 'Snapzy' CHANGELOG.md` | no matches in **header/intro** (archived upstream file may say Snapzy) |
| Extract smoke | `awk '/^## \[/{if(found) exit; found=1; next} found' CHANGELOG.md \| head -20` | non-empty body under latest version |
| First heading | `awk '/^## \[/ { print; exit }' CHANGELOG.md` | prints one `## […]` line |
| update-changelog dry | read script; ensure HEADER_END logic still finds first `## [` | — |

## Scope

**In scope**:
- `CHANGELOG.md` — re-root for Notinhas per Steps (archive + slim strategy below)
- Create `docs/CHANGELOG-upstream-snapzy.md` — full copy of pre-change CHANGELOG content (historical record)
- `docs/README.md` — one-line link to the upstream archive if docs index lists changelog-related docs
- Do **not** change `release-publish.yml` awk unless extract breaks (prefer fixing CHANGELOG shape)

**Out of scope**:
- Rewriting every historical bullet to say Notinhas
- Deleting git history
- Changing version numbers in the app

## Git workflow

- Branch: `advisor/077-reroot-changelog`
- Commit: `docs: re-root changelog for Notinhas and archive upstream history`
- Do NOT push unless instructed.

## Steps

### Step 1: Archive full current changelog

```bash
cp CHANGELOG.md docs/CHANGELOG-upstream-snapzy.md
```

Add a 3–5 line banner at the **top** of the archive file stating it is a frozen upstream Snapzy/pre-fork release history snapshot for Notinhas, and that the live file is `CHANGELOG.md`.

**Verify**: `test -f docs/CHANGELOG-upstream-snapzy.md` and archive contains `## [1.30.0-beta.12]` (or whatever the latest heading was at copy time).

### Step 2: Rewrite live CHANGELOG.md (safe slim)

Replace live `CHANGELOG.md` with:

1. Title `# Changelog`
2. Intro: “All notable changes to **Notinhas** will be documented in this file.”
3. Keep a Changelog format sentence
4. Pointer: “Upstream Snapzy release history (including Sparkle/appcast automation noise) is archived in [docs/CHANGELOG-upstream-snapzy.md](docs/CHANGELOG-upstream-snapzy.md).”
5. **Preserve the latest `## [version] - date` section in full** (copy from the file you archived — the first `## [` block only), so the next GitHub Release extract is non-empty and accurate to the last published notes.
6. Do **not** leave dozens of blank lines under the header (trim the empty padding that currently sits before the first heading).

Do **not** delete the latest section’s body. Optional: if the latest section is only appcast chore noise, still keep it verbatim for CI fidelity; future releases will prepend better notes via `update-changelog.sh`.

**Verify**:
```bash
rg -n 'Snapzy' CHANGELOG.md
```
→ no matches (pointer may say “Upstream Snapzy” — that is OK and expected once; ensure product intro says Notinhas)

```bash
awk '/^## \[/{if(found) exit; found=1; next} found' CHANGELOG.md | wc -l
```
→ ≥ 1

```bash
head -30 CHANGELOG.md
```
→ Notinhas intro + archive link + one `## [` heading soon after (no huge blank run)

### Step 3: Docs index touch

If `docs/README.md` has a documentation table, add a row for the upstream changelog archive. Skip if no suitable table.

### Step 4: Sanity with update-changelog contract

Confirm `scripts/update-changelog.sh` still finds first `## [` via its awk. Do not run it with a fake version unless you revert; reading is enough.

**Verify**: `bash -n scripts/update-changelog.sh` → exit 0

## Test plan

- Extract smoke command non-empty
- No XCTest

## Done criteria

- [ ] `docs/CHANGELOG-upstream-snapzy.md` exists with full prior content
- [ ] Live `CHANGELOG.md` intro says Notinhas
- [ ] Live file contains at least one `## [` section usable by release-publish awk
- [ ] No accidental deletion of `scripts/update-changelog.sh`
- [ ] Scope respected

## STOP conditions

- Latest version section missing/unreadable when copying — STOP
- Operator wants **zero** truncation (keep full live file) — then only fix the Snapzy header + add archive pointer **without** removing historical sections (acceptable alternate completion; document in NOTES)
- Operator wants aggressive deletion of all history from live file **and** empty extract — STOP (breaks releases)

## Maintenance notes

- New releases: use `scripts/update-changelog.sh` / release-prepare to prepend entries.
- Reviewers: open `build/changelog.md` extract simulation before approving.
- Do not reintroduce appcast chore bullets as the primary Notinhas history.
