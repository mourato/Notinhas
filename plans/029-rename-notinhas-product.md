# Plan 029: Rename the technical product identity to Notinhas

> **Executor instructions**: A Composer 2.5 subagent implements this plan in an
> isolated worktree, runs all gates, commits, merges, cleans the worktree/branch,
> and pushes. If isolation prevents integration, GPT 5.6 performs those
> operations from the returned commit. GPT 5.6 then runs
> `/thermo-nuclear-code-quality-review`, fixes every finding, commits the fixes,
> and only then starts Plan 030.
>
> **Drift check**:
> `git diff --stat 163e0f1..HEAD -- Notinhas NotinhasTests Notinhas.xcodeproj scripts .github Casks install.sh uninstall.sh reset-permissions.sh`
> must be empty.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: Plans 026, 027, and 028
- **Category**: tech-debt
- **Planned at**: `163e0f1`, 2026-07-21 (reconciled after Plan 029 review fixes)

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: no — project, module, bundle, scripts, CI, and runtime names must move atomically.
- **Reviewer required**: yes — bundle identity affects TCC, UserDefaults, Keychain, test hosts, and artifacts.
- **Rationale**: This is a physical Xcode/module rename plus a macOS identity cutover.
- **Escalate when**: old release IDs are retained, legacy readers are deleted, cloud prefixes change, or existing features are removed.

## Why this matters and current state

The project is still `Snapzy.xcodeproj`, the source/test roots are `Snapzy/`
and `SnapzyTests/`, schemes and test plan use Snapzy, and the project file uses
`com.trongduong.snapzy(.debug)`, `SNAPZY_BUNDLE_NAME`, and old product names.
`SnapzyApp.swift`, `AppIdentityManager.swift`, configuration symbols, scripts,
CI, cask, onboarding, menu, watermark, and output defaults also contain active
identity branding.

The safe boundary is to rename project/target/module/schemes/executables,
bundle IDs, identity-bound Swift symbols, app metadata, scripts, and active
branding. Keep old paths, bundle IDs, TOML aliases, sidecars, credential
extensions, and cloud object namespaces only as explicit compatibility readers.

## Commands

| Purpose | Command | Expected |
|---|---|---|
| Project | `xcodebuild -project Notinhas.xcodeproj -list` | Notinhas targets/schemes listed |
| Default/video tests | `./scripts/run-tests.sh && ./scripts/run-tests.sh --video-module` | Both exit 0 |
| Builds | `xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Debug build CODE_SIGNING_ALLOWED=NO && xcodebuild -project Notinhas.xcodeproj -scheme Notinhas -configuration Release build CODE_SIGNING_ALLOWED=NO` | Both `BUILD SUCCEEDED` |
| Bundle ID | `/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' <built-app>/Contents/Info.plist` | `com.mourato.notinhas*` |
| Identity scan | `rg -n '\\b(SnapzyApp|SnapzyDeepLink|SnapzyConfiguration|SnapzyTests|Snapzy\\.xcodeproj|com\\.trongduong\\.snapzy)\\b' Notinhas NotinhasTests Notinhas.xcodeproj scripts .github` | No active matches outside allowlisted legacy readers |
| Format | `swiftformat --lint Notinhas NotinhasTests` | No violations |

## Scope

**In scope**:

- `Snapzy.xcodeproj` → `Notinhas.xcodeproj`
- `Snapzy/` → `Notinhas/`
- `SnapzyTests/` → `NotinhasTests/`
- `Snapzy.xctestplan` → `Notinhas.xctestplan`
- shared schemes `Snapzy`/`Snapzy Video` → `Notinhas`/`Notinhas Video`
- entitlements, Info.plist, icon assets, all module imports and identity-bound
  Swift names
- AppIdentityManager, active localized/runtime branding, default output names,
  diagnostic subsystem names
- mechanically safe configuration symbol/file names; preserve old serialized
  TOML keys as importer aliases
- build/test/install/uninstall/reset scripts, cask, and CI artifact/project names
- tests needed for module, config, sidecar, and archive rename behavior

**Out of scope**: repository/remotes, `NOTINHAS_VIDEO_MODULE`, cloud APIs or
existing cloud object prefixes, deletion of old import extensions/sidecars,
`urlSchemeEnabled` key, feature rewrites, and public docs/agent guidance (Plan 030).

## Git workflow

Branch: `advisor/029-rename-notinhas-product`; commit:
`refactor: rename Snapzy product identity to Notinhas`.
Use `git mv` for physical renames and inspect status after each rename batch.

## Steps

### 1. Rename Xcode structure and bundle IDs

Rename roots/project/test plan/schemes/entitlements/icon references. Update
groups, target/test-host references, products, executable/module names, and
 build variables. Set release/debug IDs to `com.mourato.notinhas` and
`com.mourato.notinhas.debug`. The test target must stop using the old
`com.trongduong.snapzy` namespace while preserving the repository's existing
test-host suffix/convention; do not invent a third public bundle contract.
Keep video gating/configurations.

**Verify**: project list and Debug build succeed.

### 2. Rename module and identity-bound symbols

Rename `SnapzyApp` to `NotinhasApp`, imports to `Notinhas`, and any deep-link
types not already renamed. Rename configuration symbols only mechanically;
never alter persisted keys without a legacy importer. Rename identity-bound test
environment variables to `NOTINHAS_*`, but retain the video flag.

**Verify**: identity scan is clean and Debug build succeeds.

### 3. Update branding and compatibility-safe defaults

Change active UI/onboarding/permissions/menu/watermark/output/diagnostic names
to Notinhas. Export new TOML keys (`notinhas_min_version`,
`include_own_app`) while importing old keys. New sidecar/archive writes use
Notinhas names; old formats remain readable. Do not change cloud object prefixes.

**Verify**: active branding scan is clean except explicit compatibility aliases.

### 4. Update scripts, CI, cask, and build artifacts

Use `Notinhas.xcodeproj`, schemes, app names, bundle IDs, DMG names, icon paths,
and process names in scripts and workflows. Preserve legacy cleanup paths in
uninstall/reset where needed for upgrades. Keep the manual GitHub Release flow.

**Verify**: script/CI scan has no active old destination names.

### 5. Run complete builds and inspect bundle

Run default/video tests and Debug/Release builds. Inspect Info.plist,
executable, URL scheme, entitlements, and absence of Sparkle framework.

**Verify**: all commands pass; `find build -path '*Notinhas.app/Contents/Frameworks/Sparkle.framework'` returns no output.

## Test plan

Update test-host/module imports; cover new/legacy TOML keys and old sidecar/
archive readability; preserve capture → annotate → export tests and run both
video configurations.

## Done criteria

- [ ] Project, roots, targets, module, schemes, app, test host, scripts, CI,
      and active branding identify as Notinhas.
- [ ] Bundle IDs exactly match the decision.
- [ ] Plan 026 remains the only migration path and precedes DB setup.
- [ ] Compatibility readers remain and cloud namespaces are unchanged.
- [ ] Tests, builds, format, and bundle inspection pass.
- [ ] Only Scope files changed.
- [ ] Composer 2.5 commit merged, cleaned, and pushed; GPT 5.6 review findings
      fixed and committed before Plan 030.

## STOP conditions

Stop if Xcode requires unrelated regeneration, migrated data/Keychain becomes
inaccessible, a serialized format loses a reader, a cloud prefix would change,
TCC transfer is proposed, two gates fail, or an out-of-scope file is needed.

## Maintenance notes

Plan 030 must update every public path/command after this physical rename.
Review all `git mv`, test-host paths, Info.plist substitutions, and cleanup
scripts for accidental legacy-data deletion.
