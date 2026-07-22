---
name: swift-conventions
description: Swift coding conventions for Notinhas — naming, SwiftFormat, type safety, and Notinhas/NotinhasTests layout.
---

# Swift Conventions

Use when editing Swift under `Notinhas/` or `NotinhasTests/`.

## Rules

- Prefer descriptive names and small focused types or functions.
- Use early returns; keep control flow shallow.
- Avoid force unwraps unless failure is truly impossible and localized.
- Match `.swiftformat` (2-space indent, 120-column max, Swift 5.9) via `swiftformat <paths…>` from the repo root.
- Use `// MARK:` in large types for navigation.
- Keep Notinhas-specific code in `Notinhas/Features/Notinhas/`; keep Annotate/Capture integration thin.

## Layout

- App shell: `Notinhas/App/`
- Features: `Notinhas/Features/` (Notinhas under `Features/Notinhas/`)
- Services: `Notinhas/Services/`
- Tests mirror app: `NotinhasTests/Features/Notinhas/`, etc.

## Tooling

Install once: `brew install swiftformat`. Run from the repo root so `.swiftformat` applies.

```bash
# app + tests (typical)
swiftformat Snapzy NotinhasTests

# Notinhas-only
swiftformat Notinhas/Features/Notinhas NotinhasTests/Features/Notinhas

# lint without writing (CI-style)
swiftformat --lint Snapzy NotinhasTests
```

## Related

- Concurrency boundaries → `swift-concurrency-expert`
- Tests → `testing-xctest`
