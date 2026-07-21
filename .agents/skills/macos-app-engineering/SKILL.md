---
name: macos-app-engineering
description: macOS SwiftUI/AppKit implementation for Notinhas — menu bar shell, capture overlays, Annotate windows, Quick Access, and previews.
---

# macOS App Engineering

## When to Use

SwiftUI or AppKit work: menu bar shell, capture/annotate UI, floating panels, overlays, lifecycle, or preview coverage.

## Responsibilities

- Menu-bar agent lifecycle (`LSUIElement`, no Dock).
- `AppStatusBarController` — `NSStatusItem` + `NSMenu` for capture actions.
- Capture overlays, Annotate windows/panels, Quick Access floating UI.
- SwiftUI ↔ AppKit bridges at thin adapters; do not leak AppKit into every view file.
- Main-actor coordination for UI state.

## Platform Rules

- One clear owner for the status item and each major window/panel flow.
- Prefer platform APIs already in use over custom reimplementations.
- Respect Reduce Motion, Reduce Transparency, and Increase Contrast when touching materials or motion.
- Image capture and processing off the main actor where the existing code already does; hop back to MainActor for UI updates.

## Notinhas Focus

- Area capture → Annotate with Notinhas note tool (`AnnotationToolType.notinhasNote`).
- Note editor overlay (`NotinhasNoteEditorCanvasOverlay`) and side panel (`NotinhasNotesSidePanelView`).
- Export preview and clipboard-ready composition via `AnnotateExporter`.

## Preview Expectations

- Add `#Preview` for new isolated SwiftUI views under Notinhas/Annotate when practical.
- Full status-item / capture / annotate flows: verify with `./scripts/build_and_run.sh`.

## Related

- Menu-bar contracts → `menubar`
- Motion / materials → `apple-design`
- AX / permissions → `accessibility-audit`
- Visual handoff domain → `capture-annotate-export` (when present)
