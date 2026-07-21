---
name: menubar
description: Menu bar invariants for Notinhas — AppStatusBarController, NSStatusItem ownership, and capture menu behavior.
---

# Menu Bar

Use this skill for `NSStatusItem`, status-item menu behavior, and menu-bar-only app style.

## Invariants

- Register the status item once; keep its lifetime explicit in `AppStatusBarController`.
- Host capture/recording actions from the status item menu — not a separate Dock app.
- No Dock icon (`LSUIElement = true`). Do not introduce a regular activating main window for normal capture use.
- Capture and annotate menu items respect Screen Recording permission (`hasPermission` / `ScreenCaptureManager`).
- Closing/reopening menus or preferences must not create duplicate status items or controllers.
- Recording state updates the status item icon/behavior without leaking observers.

## Review Checklist

- Does `AppStatusBarController.setup` remain the single registration path?
- Are capture shortcuts and menu actions still wired through `ScreenCaptureViewModel`?
- After permission denial, are capture items disabled or prompting correctly?

## Related

- Shell implementation → `macos-app-engineering`
- Permission failures → `debugging-diagnostics`
- Visual handoff entry → `capture-annotate-export` (when present)
