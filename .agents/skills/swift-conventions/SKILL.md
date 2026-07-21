---
name: swift-conventions
description: Swift coding conventions for Notinhas — naming, SwiftFormat, type safety, and Snapzy/SnapzyTests layout.
---

# Swift Conventions

Use when editing Swift under `Snapzy/` or `SnapzyTests/`.

## Rules

- Prefer descriptive names and small focused types or functions.
- Use early returns; keep control flow shallow.
- Avoid force unwraps unless failure is truly impossible and localized.
- Match `.swiftformat` (2-space indent, 120-column max, Swift 5.9) via `swiftformat <paths…>` from the repo root.
- Use `// MARK:` in large types for navigation.
- Keep Notinhas-specific code in `Snapzy/Features/Notinhas/`; keep Annotate/Capture integration thin.

## Layout

- App shell: `Snapzy/App/`
- Features: `Snapzy/Features/` (Notinhas under `Features/Notinhas/`)
- Services: `Snapzy/Services/`
- Tests mirror app: `SnapzyTests/Features/Notinhas/`, etc.

## Tooling

Install once: `brew install swiftformat`. Run from the repo root so `.swiftformat` applies.

```bash
# app + tests (typical)
swiftformat Snapzy SnapzyTests

# Notinhas-only
swiftformat Snapzy/Features/Notinhas SnapzyTests/Features/Notinhas

# lint without writing (CI-style)
swiftformat --lint Snapzy SnapzyTests
```

## Related

- Concurrency boundaries → `swift-concurrency-expert`
- Tests → `testing-xctest`
