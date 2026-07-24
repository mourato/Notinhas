# Plan 073: Remove ghost Updates/CrashReport/About docs

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat a6128271..HEAD -- docs/STRUCTURE.md docs/SHORTCUTS.md docs/PREFERENCES.md docs/UPDATES.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
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
- **Rationale**: Docs-only alignment with already-removed Sparkle/About/CrashReport surfaces (plan 027 DONE).
- **Escalate when**: Those feature directories reappear on disk (should not).

## Why this matters

`docs/STRUCTURE.md` still lists `Features/CrashReport/`, `Features/Updates/`, `Services/Updates/`, and Preferences “About tabs”. `docs/SHORTCUTS.md` still lists settings tab `about`. Those modules were removed; wrong docs invite reintroduction and confuse agents.

## Current state

Tree excerpt (`docs/STRUCTURE.md` ~147–155, ~182):

```
    CrashReport/
    ...
    Updates/
...
    Updates/
```

Ownership table still has:

| Path | Owns |
| `Features/Preferences/` | … **About tabs** |
| `Features/Updates/` | menu binding and update UI bridge |
| `Features/CrashReport/` | Crash report prompt… |
| `Services/Updates/` | updater bootstrap |

`docs/SHORTCUTS.md:148`:

```
- Settings tabs: `general`, `capture`, `annotate`, `quick-access`, `history`, `shortcuts`, `permissions`, `cloud`, `advanced`, `about`.
```

Runtime: `PreferencesTab` has no `.about`; deep links `settings/about` / tab `about` return `nil` (covered by tests). Authoritative prefs list: `docs/PREFERENCES.md`. Authoritative no-Sparkle: `docs/UPDATES.md`.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| No ghost dirs claimed | `rg -n 'CrashReport|Features/Updates|Services/Updates|About tabs' docs/STRUCTURE.md` | no matches (or only historical notes if any — prefer none) |
| No about tab | `rg -n '`about`|, `about`|tab `about`' docs/SHORTCUTS.md` | no settings-tab about |
| Dirs absent on disk | `test ! -d Notinhas/Features/CrashReport && test ! -d Notinhas/Features/Updates && test ! -d Notinhas/Services/Updates` | exit 0 |

## Scope

**In scope**:
- `docs/STRUCTURE.md` — remove ghost tree entries and ownership rows; fix Preferences row to match `docs/PREFERENCES.md` (no About)
- `docs/SHORTCUTS.md` — remove `about` from settings tabs list; optionally one short note that `about` deep links are rejected (optional, keep brief)

**Out of scope**:
- Re-adding About/Updates/CrashReport code
- Changing deep-link handler or tests
- `CHANGELOG.md`

## Git workflow

- Branch: `advisor/073-fix-ghost-structure-docs`
- Commit: `docs: remove Updates/CrashReport/About ghosts from structure docs`
- Do NOT push unless instructed.

## Steps

### Step 1: Confirm modules absent on disk

Run the “Dirs absent on disk” command. If any directory **exists**, STOP — this plan assumes they were already removed.

### Step 2: Edit STRUCTURE.md

- Remove `CrashReport/` and `Updates/` from the Features tree.
- Remove `Updates/` from the Services tree.
- Fix Preferences ownership cell: drop “About tabs”; list real tabs consistent with `docs/PREFERENCES.md`.
- Delete ownership rows for `Features/Updates/`, `Features/CrashReport/`, `Services/Updates/`.
- Grep the rest of STRUCTURE.md for `Updates`, `CrashReport`, `About` and fix leftover false claims (keep legitimate words like “update retention” if about history retention — use judgment; do not leave Sparkle/About UI claims).

**Verify**: STRUCTURE grep from Commands table is clean of ghost module paths.

### Step 3: Edit SHORTCUTS.md

Remove `about` from the settings tabs list. Align list with live `PreferencesTab` / PREFERENCES.md.

**Verify**: `rg -n 'about' docs/SHORTCUTS.md` — if matches remain, they must not advertise a working settings tab (e.g. rejection note only). Prefer zero matches unless a rejection note is clearly useful.

## Test plan

- No code tests. Optional: `rg -n 'settings/about' NotinhasTests` still finds rejection tests — leave them.

## Done criteria

- [ ] STRUCTURE.md does not list CrashReport/Updates feature or Services/Updates roots
- [ ] Preferences docs row has no About tab
- [ ] SHORTCUTS settings tabs omit `about` as a valid tab
- [ ] No Swift/source changes

## STOP conditions

- Ghost directories exist again on disk — STOP; escalate to code removal plan first.
- PREFERENCES.md disagrees with PreferencesTab — STOP and report mismatch rather than inventing tab names.

## Maintenance notes

- Agents: treat `docs/UPDATES.md` + AGENTS.md as source of truth for “no Sparkle/About/Report”.
- Plan 027 already removed code; this plan only fixes doc drift.
