---
name: swift-concurrency-expert
description: Swift concurrency guidance for Notinhas — MainActor UI, image export/composition, and Sendable across capture boundaries.
---

# Swift Concurrency Expert

Use for actor isolation, `Sendable`, async/await, or Swift 6 concurrency diagnostics in Notinhas/Snapzy.

## Invariants

- UI, `AppStatusBarController`, and Annotate/Notinhas views stay on the **MainActor**.
- Pure geometry (`NotinhasNoteGeometry`) and export helpers may be `nonisolated` — match existing patterns.
- ImgBB upload (`NotinhasImgBBUploadService` actor, `NotinhasUploadCoordinator` on MainActor) — hop back to main actor before updating UI or publish state.
- Do not block the main thread on network, image composition, or file IO.
- Capture callbacks and exporters must marshal UI updates explicitly.
- Prefer structured concurrency over detached unstructured tasks unless lifetime is truly fire-and-forget and documented.

## Checklist

- Are `@MainActor` boundaries clear at SwiftUI/AppKit edges?
- Does new async work have a cancellation path when the annotate window closes?
- Are cross-thread image snapshots `Sendable` or copied before crossing actors?

## Related

- Export failures → `debugging-diagnostics`
- Tests → `testing-xctest`
