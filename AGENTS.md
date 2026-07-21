# Repository Guidelines

## Product Intent

Notinhas is a tailored macOS visual-handoff tool for a product designer. It
turns a screenshot into an unambiguous brief for developers and AI coding
agents: capture an area, place numbered pins or rectangles, add concise notes,
and copy the annotated result. Prioritize speed, precise visual reference, and
clipboard-ready output. Do not add broad recording, cloud, or generic markup
features unless they directly support that workflow.

## Project Structure

This repository is a fork of [Snapzy](https://github.com/duongductrong/Snapzy).
`Snapzy/` contains the app: `App/` starts the menu-bar application,
`Features/` owns user-facing flows, `Services/` holds platform and persistence
code, and `Resources/` contains assets and localization. Tests mirror the app
under `SnapzyTests/`; `docs/` and `scripts/` document and automate the
upstream project.

Keep Notinhas-specific behavior in `Snapzy/Features/Notinhas/`, with focused
models and views colocated there. Introduce small protocols or adapters in
`Services/` only where a feature needs to cross a platform boundary. Keep
integration points into the existing capture and annotation flows thin; avoid
renaming, moving, or rewriting upstream code merely to match a new design.

## Skills

Agent skills live under `.agents/skills/`. Start at `.agents/SKILLS_INDEX.md` for routing.
`project-standards` owns guidance governance (where docs live, skill template, anti-drift).
`capture-annotate-export` owns the visual handoff loop (capture → pins/notes → clipboard export).
Keep Notinhas behavior guidance aligned with Product Intent above; do not reintroduce
unrelated product skills from other apps.

## Build, Test, and Run

- `open Snapzy.xcodeproj` — develop and run in Xcode (`⌘R`).
- `./scripts/build_and_run.sh` — build and launch the isolated debug app.
- `./scripts/run-tests.sh` — run the XCTest suite with results in `build/`.
- `swiftformat <paths…>` — format Swift in place (install once:
  `brew install swiftformat`). Rules live in `.swiftformat` (two-space indent,
  120-column maximum). Scope paths as needed, e.g. `swiftformat Snapzy
  SnapzyTests` or `swiftformat Snapzy/Features/Notinhas`.

Screen Recording and Accessibility permissions are required for affected
manual checks. Test capture, annotation, clipboard output, and permission
prompts on macOS whenever they change.

### Optional Video Module

Recording and Video Editor are optional. They compile only when
`NOTINHAS_VIDEO_MODULE` is set (scheme **Snapzy Video** with **Debug+Video** /
**Release+Video**). The default **Snapzy** scheme keeps the module off.
`./scripts/build_and_run.sh` prompts interactively or accepts `--video-module`,
`--no-video-module`, or `ENABLE_VIDEO_MODULE=1|0`. At runtime,
`videoModule.enabled` defaults to off; when the module is compiled in, turn it
on under **Preferences → Advanced** (`VideoModuleAvailability`). Notinhas
capture → annotate → export does not require the Video module.
`./scripts/run-tests.sh` uses the default **Snapzy** scheme, so
Recording/VideoEditor XCTests are compiled out unless you run tests with the
Video scheme and **Debug+Video** configuration.

## Code and Tests

Use Swift 5.9 conventions: `UpperCamelCase` types, `lowerCamelCase` members,
descriptive file names, and `// MARK:` in large types. Keep UI work on the
main actor; move capture, file, and image processing off it. Add XCTest cases
in the matching `SnapzyTests/` area, named by behavior—for example,
`testPinNoteExportKeepsMarkerOrder()`.

## Fork and Contribution Workflow

`origin` is `mourato/Notinhas`; `upstream` is `duongductrong/Snapzy`. Before
starting substantial work, run `git fetch upstream`. Bring upstream changes in
as focused merge or rebase commits, resolve conflicts without deleting
Notinhas modules, and validate the affected flow afterward. Keep commits
atomic and Conventional (`feat: add numbered callouts`, `fix: copy annotation
to clipboard`). Pull requests state the user outcome, validation performed,
upstream conflicts or compatibility risks, and include screenshots or a short
recording for UI changes.
