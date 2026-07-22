# Plan 030: Complete Notinhas documentation and final validation

> **Executor instructions**: A Composer 2.5 subagent implements this plan in an
> isolated worktree, runs all gates, commits, merges, cleans the worktree/branch,
> and pushes. If isolation prevents integration, GPT 5.6 performs those
> operations from the returned commit. GPT 5.6 then runs
> `/thermo-nuclear-code-quality-review`, fixes every finding, commits the fixes,
> and marks the separation program complete.
>
> **Drift check**:
> `git diff --stat 5bc63c6..HEAD -- README* AGENTS.md CONTRIBUTING.md SECURITY.md docs .agents .github/ISSUE_TEMPLATE .github/workflows/release-notify.yml`
> must be empty.

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: MED
- **Depends on**: `plans/029-rename-notinhas-product.md`
- **Category**: docs
- **Planned at**: `5bc63c6`, 2026-07-21 (reconciled after Plan 030 review fixes)

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `Medium/Full`
- **Parallelizable**: no — docs must match final source/project paths and release behavior.
- **Reviewer required**: yes — stale docs can restore removed upstream identity or features.
- **Rationale**: Textual changes are broad and the final manual acceptance gates are product-critical.
- **Escalate when**: a new distribution/support/update channel is needed or validation finds a runtime regression.

## Why this matters and current state

The current README and localized READMEs install Snapzy, describe `snapzy://`,
Sparkle, About, upstream support, and old build paths. `docs/BUILD.md`,
`CONFIGURATION.md`, `PREFERENCES.md`, `SHORTCUTS.md`, `APP_LIFECYCLE.md`,
`STRUCTURE.md`, `RELEASES.md`, `UPDATES.md`, and `UPDATE_TESTING.md` repeat
those contracts. `AGENTS.md` and local workflow skills still direct agents to
Snapzy paths. Issue templates and release notifications also use old branding.

The final docs must describe Notinhas, manual GitHub Releases/DMGs, migration
and TCC reauthorization, `notinhas://`, local diagnostics, and the core
capture → annotate → export/clipboard workflow. Do not publish secrets or
invent a support endpoint.

## Commands

| Purpose | Command | Expected |
|---|---|---|
| Tests | `./scripts/run-tests.sh && ./scripts/run-tests.sh --video-module` | Both exit 0 |
| Builds | `xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO && xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Release build CODE_SIGNING_ALLOWED=NO` | Both succeed |
| Docs residue | `rg -n 'Snapzy|snapzy|Sparkle|appcast|Report a Problem|Report Issue|PreferencesAbout|Check for Updates|settings\\?tab=about' README* AGENTS.md CONTRIBUTING.md SECURITY.md docs .agents .github` | No active matches except explicitly labelled legacy compatibility |
| Source residue | `rg -n 'Snapzy|snapzy|Sparkle|appcast|CrashReport|PreferencesAbout|Check for Updates' Notinhas NotinhasTests Notinhas.xcodeproj scripts .github Casks install.sh uninstall.sh reset-permissions.sh` | Only compatibility readers/rejection tests |
| Bundle | `plutil -p <built-app>/Contents/Info.plist` | Notinhas identity, `notinhas`, no Sparkle keys |
| Framework | `find build -path '*Notinhas.app/Contents/Frameworks/Sparkle.framework'` | No output |
| Diff hygiene | `git diff --check` | No errors |

## Scope

**In scope**:

- `README.md`, `README.vi.md`, `README.zh-CN.md`
- `AGENTS.md`, `CONTRIBUTING.md`, `SECURITY.md`
- `.agents/SKILLS_INDEX.md` and affected local skills under
  `.agents/skills/`
- `.github/ISSUE_TEMPLATE/bug_report.yml`,
  `.github/ISSUE_TEMPLATE/feature_request.yml`,
  `.github/workflows/release-notify.yml`
- `docs/README.md`, `DEVELOPMENT.md`, `BUILD.md`, `PREFERENCES.md`,
  `SHORTCUTS.md`, `APP_LIFECYCLE.md`, `STRUCTURE.md`, `CONFIGURATION.md`,
  `SECURITY.md`, `RELEASES.md`, `UPDATES.md`, `UPDATE_TESTING.md`,
  and new `docs/MIGRATION.md`

**Out of scope**: runtime source/project changes, new telemetry/support/update
systems, issue publication, repository visibility, and rewriting historical
user-generated content solely to erase Snapzy.

## Git workflow

Branch: `advisor/030-docs-and-delivery-validation`; commit:
`docs: complete Notinhas separation and delivery guide`.

## Steps

### 1. Rewrite public and technical docs

Use Notinhas identity, final project/scheme/app paths, `notinhas://`, manual
GitHub Releases/DMG distribution, and current feature descriptions. Remove
Sparkle/update/About/Report a Problem claims. Add `docs/MIGRATION.md` covering
legacy Application Support/database/WAL/SHM/log/config/UserDefaults/Keychain
inputs, non-destructive/idempotent behavior, old-scheme rejection, and
mandatory Screen Recording/Accessibility/Microphone reauthorization after the
bundle-ID change. Delete or replace Sparkle-only update docs.

**Verify**: docs residue command has no unexplained active matches.

### 2. Update agent guidance and repository workflows

Update AGENTS and only the affected local skills to teach Notinhas paths,
commands, optional video behavior, product intent, and the rule not to restore
removed upstream integrations. Update issue templates/release notifications
without adding a support funnel or sensitive operational details.

**Verify**: the same residue scan over AGENTS, skills, and `.github` is clean.

### 3. Classify all remaining compatibility references

For every remaining old string, classify it as legacy migration source, old
import format, external cloud namespace, intentional old-scheme rejection, or
historical content. Any unexplained active branding is in scope to fix; any
runtime issue stops this documentation plan rather than changing source.

**Verify**: classification is recorded in review notes and `git diff --check` passes.

### 4. Run automated and manual acceptance

Run default/video tests and Debug/Release builds; inspect bundle identity,
scheme, entitlements, and absence of Sparkle. On macOS:

- launch Notinhas and confirm menu/quit name with no About/update/report UI;
- validate a migration fixture opens captures/history/preferences/logs;
- regrant new TCC permissions;
- capture an area, add pins/rectangles and notes, export/copy, and paste;
- verify `notinhas://capture/area` works and `snapzy://capture/area` is ignored;
- if configured, complete Google Drive OAuth and verify the new callback.

Record unavailable permissions/cloud credentials as skipped, never as passed.

**Verify**: both test commands and manual gates have explicit evidence.

## Test plan

No new runtime unit test is required for docs. Re-run migration, deep-link,
configuration, diagnostics, default, video, and capture → annotate → clipboard
tests from Plans 026–029.

## Done criteria

- [ ] README/docs/AGENTS/skills/templates/release notifications match final code.
- [ ] `docs/MIGRATION.md` documents data migration, old URL rejection, and TCC.
- [ ] No unexplained active Snapzy/Sparkle/About/report/update references remain.
- [ ] Tests, builds, bundle inspection, and diff hygiene pass.
- [ ] Core manual handoff flow is passed or skipped with an explicit reason.
- [ ] Only Scope files changed.
- [ ] Composer 2.5 commit merged, cleaned, and pushed.
- [ ] GPT 5.6 thermo review findings fixed and committed; index marks Plans
      026–030 DONE only after this gate.

## STOP conditions

Stop if docs cannot be reconciled with runtime, a release URL must be invented,
a public template would expose sensitive data, residue is actually a runtime
bug, permissions are unclear, two gates fail, or an out-of-scope file is needed.

## Maintenance notes

Keep `docs/MIGRATION.md` synchronized with future legacy-path/Keychain/TOML
changes. Update README, release docs, scripts, cask, and workflow together when
the distribution channel changes. TCC grants remain non-migratable.
