---
name: delivery-workflow
description: Delivery and verification workflow for Notinhas — scripts/build_and_run.sh, XCTest, signing, manual capture/annotate gates, and Git evidence.
---

# Delivery Workflow

## When to Use

Build/run failures, choosing verification depth, assessing merge readiness, or Git/PR evidence.

## Command Routing

| Command | Purpose |
| ------- | ------- |
| `open Notinhas.xcodeproj` | Develop and run in Xcode (`⌘R`). Default scheme **Notinhas** = Video module off. |
| `./scripts/build_and_run.sh` | **Canonical** build and launch for the isolated debug app (codesign via `LOCAL_CODE_SIGN_IDENTITY`, default `Prisma Local Code Signing`). Interactive prompt asks whether to include the Video module; non-interactive: `--video-module`, `--no-video-module`, or `ENABLE_VIDEO_MODULE=1` / `0`. |
| `./scripts/launch.sh` | **Legacy compatibility** only — forwards to `./scripts/build_and_run.sh --logs`. Prefer the canonical command for verify, telemetry, Video module, and other options. |
| `./scripts/build_and_run.sh --video-module` | Build with Recording + Video Editor (`Notinhas Video` scheme, **Debug+Video** / **Release+Video**). |
| `./scripts/build_and_run.sh --no-video-module` | Explicit default: **Notinhas** scheme, module off. |
| `./scripts/run-tests.sh` | Run the XCTest suite with default **Notinhas** scheme (**Debug**); results under `build/`. Recording/VideoEditor tests are **not** compiled in. |
| `./scripts/run-tests.sh --video-module` | Run Recording/VideoEditor XCTests (**Notinhas Video** / **Debug+Video**). Also: `ENABLE_VIDEO_MODULE=1` or `--no-video-module`. |
| `./scripts/run-tests.sh --skip-visual` | Local focus aid: skip suites that order real overlays/panels onto the display (`NOTINHAS_SKIP_VISUAL_TESTS=1`). Not a merge-gate substitute when capture overlay / Quick Access / status-bar activation change. Area-selection backdrop grabs default to synthetic under XCTest (no Screen Recording TCC); opt into live capture with `NOTINHAS_ALLOW_SCREEN_CAPTURE_IN_TESTS=1`. |
| `./scripts/plan-preflight.sh plans/NNN-*.md --scope <path> [--new-file <path>]` | Read-only plan preflight (dependency, scope, drift, worktree). Prefer `build/plan-preflight/` for JSON evidence. |
| `./scripts/verify-local.sh --base <ref> --plan-only` | Changed-surface verification planner: maps touched paths to XCTest selectors, shell checks, and manual gates. Add `--strict` to fail on unmapped/manual-required paths; add `--execute` to run deterministic checks. Does **not** replace the full suite or manual TCC/WindowServer gates. |
| `swiftformat <paths…>` | Format Swift in place (`brew install swiftformat`; `.swiftformat`: 2-space indent, 120 columns). Scope paths as needed — e.g. `swiftformat Notinhas NotinhasTests`. |

Do **not** treat plain `swift build` as sufficient acceptance — Info.plist, signing, and Screen Recording permissions matter for capture flows.

### Optional Video Module

- **Compile gate:** `NOTINHAS_VIDEO_MODULE` — set by **Notinhas Video** scheme configurations **Debug+Video** / **Release+Video**. Default **Notinhas** scheme excludes Recording and Video Editor sources and their XCTests (`#if NOTINHAS_VIDEO_MODULE`).
- **Runtime gate:** `VideoModuleAvailability` — UserDefaults key `videoModule.enabled`, default off; Advanced preferences toggle when compiled in.
- **Notinhas merge gate:** default `./scripts/run-tests.sh` (module off) is sufficient for capture/annotate/export work. Run `./scripts/run-tests.sh --video-module` when touching Recording, Video Editor, or video-gated shell/prefs/history paths.

## Signing Note

Screen Recording and Accessibility TCC grants follow the code signature. Ad-hoc or changed signing identities can reset grants. For local persistence checks, run `scripts/test-tcc-local.sh` (`build-v1` → grant permissions manually → `build-v2` → optional `compare`). The helper defaults to an isolated install under `/tmp/test-tcc-notinhas/Applications/Notinhas.app`, writes stage metadata under `/tmp/test-tcc-notinhas/reports/`, and requires `--install-path` plus `--allow-system-install` to replace `/Applications/Notinhas.app`. Permission persistence still requires manual observation in System Settings.

## Validation Scope

### Merge Gate (current)

1. `swiftformat <paths…>` on the Swift paths you changed (or confirm no Swift changes). Typical scope: `swiftformat Notinhas NotinhasTests`.
2. `./scripts/verify-local.sh --base <integration-ref> --plan-only --strict` when you need a conservative changed-surface plan before running tests.
3. `./scripts/run-tests.sh` for logic touched, `./scripts/verify-local.sh --base <integration-ref> --execute` for mapped deterministic subsets, or filtered `-only-testing:` for focused suites.
4. Manual smoke appropriate to the diff (below)

`verify-local` narrows deterministic local feedback. It does **not** replace `./scripts/run-tests.sh` without `--full`, visual suites, or manual capture/TCC/WindowServer checks when the touched surface requires them.

### Scope Matrix

- Pure refactor / docs: tests relevant to change + `./scripts/build_and_run.sh` once if shell paths touched.
- Notinhas notes / export / geometry: run `NotinhasTests/Features/Notinhas/*` suites; manual capture → annotate → copy brief.
- Capture / permissions: confirm Screen Recording grant path; menu items disabled when permission missing.
- Persistence: relaunch; confirm Notinhas session restore and ImgBB key round-trip (key name only in logs).
- Upstream merge: `./scripts/run-tests.sh` + capture/annotate smoke; preserve
  `Notinhas/Features/Notinhas/`.

## Git Evidence

- Prefer granular commits (one logical change); Conventional Commits (`feat(notinhas):`, `fix:`, `docs(agents):`).
- Summarize what was built and which manual checks ran.
- Do not commit secrets, API keys, or personal capture dumps.

## Related

- Domain behavior → narrowest skill in `.agents/skills/` (see `project-standards` when routing or policy is unclear)
- Capture → annotate → export loop → `capture-annotate-export` (when added)
- Strict review → global `thermo-nuclear-code-quality-review` if available in the executor environment
