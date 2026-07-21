---
name: testing-xctest
description: XCTest guidance for Notinhas — geometry, composer, annotate state, ImgBB parsing, and SnapzyTests layout.
---

# Testing (XCTest)

Use when adding or changing automated tests under `SnapzyTests/`.

## When Adding Tests

- Prefer pure logic first: `NotinhasNoteGeometry`, `NotinhasNotesComposer`, `NotinhasNoteRenderer`, `NotinhasAnnotateState` undo/move, ImgBB response parsing.
- Keep UI/AppKit lifecycle (status item, capture overlay, full annotate window) as manual checks unless a seam is introduced.
- Use fakes for `UserDefaults` or network boundaries when testing configuration/upload services.
- Mark UI-touching tests `@MainActor` when they construct views or main-actor types.

## Structure

- Mirror source names: `SnapzyTests/Features/Notinhas/NotinhasNoteGeometryTests.swift`, etc.
- One behavior per test name; assert observable outcomes, not private implementation details.

## Commands

```bash
./scripts/run-tests.sh
./scripts/run-tests.sh -only-testing:SnapzyTests/NotinhasNoteGeometryTests
```

## Related

- Delivery gate → `delivery-workflow`
- Domain behavior under test → `capture-annotate-export` (when present)
