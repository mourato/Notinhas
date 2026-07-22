# Agent Skills Index

Start here to route work to the narrowest skill. For governance (where docs live, skill template, anti-drift), use `project-standards`. For build/test/format commands, use `delivery-workflow`.

## Routing

- Prefer the **narrowest domain skill** for implementation work.
- Notinhas pin/note/export/clipboard scope → `capture-annotate-export` first (when present).
- AGENTS/skills/index policy → `project-standards`.
- Commands and merge gates → `delivery-workflow`.

## Skills

| Skill | Owns | Reach for when… |
|-------|------|-----------------|
| `capture-annotate-export` | Visual handoff loop | Notinhas pins/notes, export composition, clipboard brief, ImgBB from annotate, scope questions |
| `project-standards` | Guidance governance | Updating AGENTS, skill registry, docs routing, known limitations |
| `delivery-workflow` | Build, test, format, signing | Merge gates, `./scripts/*`, manual smoke scope |
| `plan-execute-review` | Advisor→executor→thermo loop | Executing `plans/NNN-*.md` with Composer 2.5 / GPT 5.6 Medium, merge/push, and thermo finding fixes |
| `documentation` | README, AGENTS, docs/, MARK | Project docs ownership and agent guide edits |
| `macos-app-engineering` | SwiftUI/AppKit shell | Menu bar, capture overlays, Annotate windows, previews |
| `menubar` | NSStatusItem / menu | Status item lifetime, capture menu behavior |
| `apple-design` | Visual polish | Annotate chrome, note editor, materials, motion |
| `accessibility-audit` | AX review | VoiceOver labels, permissions UX, Reduce Motion/Contrast |
| `debugging-diagnostics` | Troubleshooting | Permissions, signing/TCC, export/clipboard, ImgBB errors |
| `data-persistence` | Session / UserDefaults | Notinhas session restore, ImgBB key name, panel side prefs |
| `swift-concurrency-expert` | Actors / async | MainActor UI, export/upload isolation |
| `swift-conventions` | Swift style | Naming, SwiftFormat, Notinhas layout |
| `testing-xctest` | XCTest | `NotinhasTests/`, especially `Features/Notinhas/` |
| `localization` | Strings | xcstrings, NotinhasL10n, accessible copy |
| `code-quality` | Refactors | Deduplication, dead code, fork coherence |

## Product Intent (summary)

Notinhas turns a screenshot into a clipboard-ready brief: capture an area, numbered pins/rects, concise notes. Do not expand into broad recording, cloud, or generic markup unless it directly serves that loop. Full intent: `AGENTS.md`.
