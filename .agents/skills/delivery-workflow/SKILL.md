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
| `open Snapzy.xcodeproj` | Develop and run in Xcode (`⌘R`) |
| `./scripts/build_and_run.sh` | Build and launch the isolated debug app (codesign via `LOCAL_CODE_SIGN_IDENTITY`, default `Prisma Local Code Signing`) |
| `./scripts/run-tests.sh` | Run the XCTest suite; results under `build/` |
| `swiftformat <paths…>` | Format Swift in place (`brew install swiftformat`; `.swiftformat`: 2-space indent, 120 columns). Scope paths as needed — e.g. `swiftformat Snapzy SnapzyTests`. |

Do **not** treat plain `swift build` as sufficient acceptance — Info.plist, signing, and Screen Recording permissions matter for capture flows.

## Signing Note

Screen Recording and Accessibility TCC grants follow the code signature. Ad-hoc or changed signing identities can reset grants. See `scripts/test-tcc-local.sh` when debugging permission regressions after rebuilds.

## Validation Scope

### Merge Gate (current)

1. `swiftformat <paths…>` on the Swift paths you changed (or confirm no Swift changes). Typical scope: `swiftformat Snapzy SnapzyTests`.
2. `./scripts/run-tests.sh` for logic touched, or filtered `-only-testing:` for focused suites
3. Manual smoke appropriate to the diff (below)

### Scope Matrix

- Pure refactor / docs: tests relevant to change + `./scripts/build_and_run.sh` once if shell paths touched.
- Notinhas notes / export / geometry: run `SnapzyTests/Features/Notinhas/*` suites; manual capture → annotate → copy brief.
- Capture / permissions: confirm Screen Recording grant path; menu items disabled when permission missing.
- Persistence: relaunch; confirm Notinhas session restore and ImgBB key round-trip (key name only in logs).
- Upstream Snapzy merge: `./scripts/run-tests.sh` + capture/annotate smoke; preserve `Snapzy/Features/Notinhas/`.

## Git Evidence

- Prefer granular commits (one logical change); Conventional Commits (`feat(notinhas):`, `fix:`, `docs(agents):`).
- Summarize what was built and which manual checks ran.
- Do not commit secrets, API keys, or personal capture dumps.

## Related

- Domain behavior → narrowest skill in `.agents/skills/` (see `project-standards` / `SKILLS_INDEX.md` when present)
- Capture → annotate → export loop → `capture-annotate-export` (when added)
- Strict review → global `thermo-nuclear-code-quality-review` if available in the executor environment
