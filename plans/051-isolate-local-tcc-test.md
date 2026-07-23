# Plan 051: Make the local TCC test isolated and auditable

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat d4c52d12..HEAD -- scripts/test-tcc-local.sh docs/SELF_SIGNED_CERT.md docs/UPDATE_TESTING.md .agents/skills/debugging-diagnostics/SKILL.md .agents/skills/delivery-workflow/SKILL.md`

## Status

- **Priority**: P2
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: none
- **Category**: security
- **Planned at**: commit `f31ab568`, 2026-07-23

## Execution profile

- **Recommended profile**: `implementer`
- **Risk/lane**: `High/Full`
- **Parallelizable**: yes — independent from 047–050; workstream is local TCC/signing diagnostics.
- **Reviewer required**: yes — the script installs and replaces an application bundle and must fail safely.
- **Rationale**: The change is operationally bounded but touches permissions, signing, installation paths, cleanup, and user data safety.
- **Escalate when**: preserving TCC behavior requires changing bundle identifiers, entitlements, signing identities, or the application’s installed release path.

## Why this matters

The TCC helper is intended to verify that a stable signing identity preserves Screen Recording and Microphone grants across a reinstall. It currently targets `/Applications/Notinhas.app`, kills the running app, removes the target, and copies a test bundle into place. An interrupted diagnostic can therefore damage the user’s installed application, while its output does not provide a structured record of which archive, signature, and install target were tested.

The fix must preserve the test’s purpose and its mandatory manual permission checks. It should default to an isolated install location, require an explicit opt-in for a system installation path, and write a small metadata report without recording credentials or permission contents.

## Current state

- `scripts/test-tcc-local.sh:16-20` sets a fixed `/tmp/test-tcc-notinhas` workspace, certificate name, entitlements path, and `/Applications/Notinhas.app` install path.
- `scripts/test-tcc-local.sh:22-55` builds and reuses archives by stage label.
- `scripts/test-tcc-local.sh:57-105` copies the archive, preprocesses entitlements, signs, verifies, kills Notinhas, removes the install target, and copies the test app into it.
- `scripts/test-tcc-local.sh:126-158` defines `build-v1`, `build-v2`, and ad-hoc `compare`; `build-v2` intentionally reuses the `v1` archive to test re-sign/reinstall behavior, while `compare` intentionally uses ad-hoc signing.
- `docs/SELF_SIGNED_CERT.md:38-61` documents the three-stage manual flow and its `clean` command.
- `docs/UPDATE_TESTING.md:27-29` points users to the TCC helper as a local diagnostic.
- `.agents/skills/delivery-workflow/SKILL.md:33-35` states that TCC follows the code signature and points to this helper for permission regressions.

Do not change the bundle identifier or signing identity as part of this plan. Do not claim that a command-line check can prove the permission state; the user must still open the app and inspect System Settings/behavior.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Syntax | `bash -n scripts/test-tcc-local.sh` | exit 0 |
| Help | `./scripts/test-tcc-local.sh help` | documents isolated default target, explicit system-install opt-in, reports, and manual permission steps |
| Static safety check | `rg -n "/Applications/Notinhas\.app|rm -rf|install|report|archive" scripts/test-tcc-local.sh docs/SELF_SIGNED_CERT.md docs/UPDATE_TESTING.md` | output reflects guarded installation and documented cleanup/report behavior |
| Hygiene | `git diff --check` | no whitespace errors |

## Scope

**In scope**:

- `scripts/test-tcc-local.sh` — safe target selection, guarded installation, stage metadata, and cleanup.
- `docs/SELF_SIGNED_CERT.md` — updated safe test flow.
- `docs/UPDATE_TESTING.md` — diagnostic usage and safety note.
- `.agents/skills/debugging-diagnostics/SKILL.md` — local TCC troubleshooting routing.
- `.agents/skills/delivery-workflow/SKILL.md` — command contract and manual gate wording.

**Out of scope**:

- Application bundle IDs, entitlements, signing certificates, release workflows, or TCC database manipulation.
- Automatic granting/revoking of Screen Recording, Accessibility, or Microphone permissions.
- Changes to `scripts/create-signing-cert.sh`.
- Running the test against the user’s real `/Applications` installation during implementation.

## Git workflow

- Branch: `advisor/051-isolate-local-tcc-test` or the active isolated implementation branch.
- Commit message: `fix: isolate local tcc verification`.
- Merge and push remain mandatory after executor and review gates.

## Steps

### Step 1: Add explicit target and safety configuration

Change the default install target to an app path under the fixed test workspace, for example `$TEST_DIR/Applications/Notinhas.app`. Add an explicit `--install-path PATH` option and an `--allow-system-install` opt-in. Refuse any path under `/Applications` unless both the explicit path and opt-in are present; in an interactive terminal, require a confirmation naming the exact target. In non-interactive mode, refuse the system path unless the opt-in is present and the target is exact.

Keep path handling free of unresolved globs and broad recursive deletion. Before replacing any existing explicit target, record whether it existed and create a backup under the test workspace. Register an EXIT trap that restores the backup after a failed install or interrupted run; successful runs must leave the isolated test app and metadata available for manual inspection.

**Verify**: `./scripts/test-tcc-local.sh help` → shows safe default and explicit system-install guard; a dry argument-validation path with `/Applications/Notinhas.app` and no opt-in exits non-zero without deleting or copying anything.

### Step 2: Record stage and signature metadata

For each `build-v1`, `build-v2`, and `compare` stage, write a metadata file under the test workspace containing only non-secret facts: stage label, archive path, source commit if available, bundle identifier, install path, signing identity label, whether the identity is self-signed or ad-hoc, timestamp, and verification result. Never record certificate private material, passwords, API keys, or permission database contents.

Preserve the intentional semantics: `build-v2` may reuse the `v1` archive because it tests a same-source re-sign/reinstall; label that explicitly instead of implying a second source build. `compare` remains the ad-hoc control case.

**Verify**: after a validation-only or help path, no metadata is written outside the test workspace; after a configured test stage, the report contains the stage and archive label without secret values.

### Step 3: Harden installation and cleanup

Refactor `sign_and_install` so it validates the archive/app source before any target removal, never kills or removes a target until the guard and backup are ready, and restores the previous target if `ditto` or signature verification fails. Make `clean` operate only on the exact fixed test workspace or an explicitly validated workspace path; it must not accept `/`, the repository root, `/Applications`, or an empty path.

Keep the manual flow visible: launch the isolated app, grant permissions, run `build-v2`, and inspect whether grants persist. The script should print the exact app path and report path for each stage.

**Verify**: `bash -n scripts/test-tcc-local.sh && git diff --check` → exit 0; static inspection confirms no default operation removes `/Applications/Notinhas.app`.

### Step 4: Update troubleshooting documentation

Update the two docs and both relevant skills to show the isolated default flow, the explicit system-install override, the metadata report, and the fact that the permission result still requires manual observation. Preserve the existing explanation that TCC follows code signature and that ad-hoc signing is a comparison control, not the normal path.

**Verify**: `rg -n "isolat|system|allow-system|report|build-v1|build-v2|compare|manual" scripts/test-tcc-local.sh docs/SELF_SIGNED_CERT.md docs/UPDATE_TESTING.md .agents/skills/debugging-diagnostics/SKILL.md .agents/skills/delivery-workflow/SKILL.md` → the safety contract and manual gate are consistent.

## Test plan

- Shell syntax and help/argument validation without building or installing an app.
- Static checks for guarded system paths and exact cleanup targets.
- If a configured self-signed certificate is available, run the full three-stage flow only in the isolated default target and manually inspect the reported app path before granting permissions.
- Do not run a system-target installation as part of automated verification.

## Done criteria

- [ ] Default operation never replaces `/Applications/Notinhas.app`.
- [ ] System installation requires explicit target and opt-in guard.
- [ ] Failed installation restores any pre-existing explicit target.
- [ ] `build-v1`, `build-v2`, and `compare` semantics are preserved and labeled accurately.
- [ ] Reports contain stage/signature/path metadata but no secrets or permission database contents.
- [ ] Cleanup rejects broad or unresolved targets.
- [ ] Documentation preserves the manual permission gate.
- [ ] Shell syntax, help, static safety checks, and `git diff --check` pass.
- [ ] `plans/README.md` status row for 051 is updated.

## STOP conditions

- TCC behavior requires changing bundle IDs, entitlements, certificate identities, or application product code.
- The platform does not preserve the required permission behavior when the default target is isolated; stop and report rather than silently falling back to `/Applications`.
- Safe backup/restore cannot be guaranteed for an explicitly requested system target.
- A proposed report would contain credentials, private key material, permission database contents, or full diagnostic logs.

## Maintenance notes

TCC tests remain inherently manual and machine-dependent. Reviewers should inspect target validation, backup/restore traps, and the exact paths used by `rm`, `mv`, and `ditto`. Keep the system-install path opt-in even if it is convenient during future debugging.
