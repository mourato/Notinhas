# Plan 074: Prune empty About and crash-report localization scaffolding

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat a6128271..HEAD -- Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/manifest.json Notinhas/Resources/Localization/Shared/Errors.xcstrings Notinhas/Resources/Localization/Features/Settings.xcstrings`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: tech-debt
- **Planned at**: commit `a6128271`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes`
- **Reviewer required**: `no`
- **Rationale**: Empty prefixes only; CatalogTool verify is the gate.
- **Escalate when**: Non-empty `preferences-about.*` or `crash-report.*` keys appear in catalogs.

## Why this matters

About / Report a Problem UI is gone, but `manifest.json` and `L10n.tableMappings` still route `preferences-about.` → Settings and `crash-report.` → Errors. `Errors.xcstrings` has **zero** strings; Settings has **zero** about keys. That scaffolding implies removed surfaces still exist.

## Current state

`L10n.swift` tableMappings include:

```21:29:Notinhas/Shared/Localization/L10n.swift
    ("crash-report.", "Errors"),
    ...
    ("preferences-about.", "Settings"),
```

`manifest.json` Settings prefixes include `"preferences-about."`; Errors fragment prefixes are only `"crash-report."`.

`Errors.xcstrings` → `"strings": {}` (empty).
Settings → no `preferences-about*` keys.

`L10n.WhatsNew` enum accessors exist but FeatureIntro resolves `whats-new.*` via `LocalizedStringKey` + table — **keep** `whats-new.` mapping and `WhatsNew.xcstrings`. Optionally remove unused `enum WhatsNew` static accessors only if `rg` shows zero `L10n.WhatsNew` call sites (confirmed unused at plan time). Prefer keeping WhatsNew enum if unsure — **required** work is about/crash-report only.

Localization conventions: `docs/LOCALIZATION.md`; verify with CatalogTool.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Catalog verify | `swift -module-cache-path build/swift-module-cache tools/localization/CatalogTool.swift verify` | exit 0 |
| No prefixes | `rg -n 'preferences-about\.|crash-report\.' Notinhas/Shared/Localization/L10n.swift Notinhas/Resources/Localization/manifest.json` | no matches |
| Empty Errors OK | `python3 -c "import json; d=json.load(open('Notinhas/Resources/Localization/Shared/Errors.xcstrings')); assert d.get('strings')=={}"` | exit 0 **before** delete — after plan, either delete Errors fragment if unused or leave empty file only if still referenced |

## Scope

**In scope**:
- `Notinhas/Shared/Localization/L10n.swift` — remove `crash-report.` and `preferences-about.` from `tableMappings`
- `Notinhas/Resources/Localization/manifest.json` — remove those prefixes from fragment prefix lists
- If `Errors.xcstrings` becomes an empty catalog with **no** prefixes left pointing at it, either:
  - **Preferred**: delete `Shared/Errors.xcstrings` **and** remove its fragment entry from `manifest.json`, **or**
  - Keep the empty file only if CatalogTool/Xcode still requires the fragment — follow CatalogTool verify
- Optional: remove unused `enum WhatsNew` accessors in `L10n.swift` **only if** `rg 'L10n\.WhatsNew' Notinhas NotinhasTests` is empty; do **not** delete WhatsNew.xcstrings or whats-new mapping

**Out of scope**:
- Regenerating all of L10n.swift wholesale
- FeatureIntro / WhatsNew campaigns content
- Adding new About UI

## Git workflow

- Branch: `advisor/074-prune-about-crash-l10n`
- Commit: `chore: prune empty About and crash-report localization scaffolding`
- Do NOT push unless instructed.

## Steps

### Step 1: Confirm catalogs still empty

```bash
python3 -c "import json; d=json.load(open('Notinhas/Resources/Localization/Shared/Errors.xcstrings')); print(len(d.get('strings',{})))"
python3 -c "import json; d=json.load(open('Notinhas/Resources/Localization/Features/Settings.xcstrings')); print([k for k in d.get('strings',{}) if 'about' in k.lower()])"
```
→ Errors count `0`; about keys `[]`. If not, STOP.

### Step 2: Edit manifest + L10n mappings

Remove `preferences-about.` and `crash-report.` prefixes. If Errors fragment has no prefixes left, remove the fragment entry and delete `Errors.xcstrings`.

**Verify**: prefix `rg` clean; JSON still valid (`python3 -m json.tool …`).

### Step 3: CatalogTool verify

```bash
swift -module-cache-path build/swift-module-cache tools/localization/CatalogTool.swift verify
```
→ exit 0

### Step 4 (optional): WhatsNew accessors

If `rg -n 'L10n\.WhatsNew' Notinhas NotinhasTests` is empty, delete `enum WhatsNew { … }` block only. Keep whats-new table mapping.

**Verify**: CatalogTool verify still passes; FeatureIntro still builds conceptually (no need full app build if unchanged).

## Test plan

- CatalogTool verify is the gate.
- No XCTest changes expected.

## Done criteria

- [ ] No `preferences-about.` / `crash-report.` in L10n mappings or manifest
- [ ] CatalogTool verify exits 0
- [ ] WhatsNew.xcstrings and whats-new routing preserved
- [ ] Scope respected

## STOP conditions

- Non-empty about/crash-report strings exist — STOP (need content migration plan).
- CatalogTool fails after edits twice — STOP and report.
- Removing Errors.xcstrings breaks Xcode project references — fix pbxproj only if the file was explicitly listed; if unclear, keep empty Errors.xcstrings + a harmless unused prefix is worse — prefer fixing project reference. Only touch `project.pbxproj` if required for deleted file reference; if so, that file becomes in-scope for this plan.

## Maintenance notes

- Do not re-add preferences-about without restoring About UI (forbidden by AGENTS.md).
- Reviewers: confirm WhatsNew campaigns still resolve strings.
