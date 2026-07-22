---
name: apple-design
description: Motion, materials, and typography feel for Notinhas UI — annotate chrome, note editor, Quick Access, aligned with system accessibility settings.
---

# Apple Design

Use when changing annotate visuals, note editor chrome, Quick Access cards, materials, springs, or typography.

## Invariants

- Prefer system materials and patterns already used in Notinhas/Annotate over bespoke chrome.
- Reuse existing spacing, radii, and color patterns from neighboring Annotate/Notinhas views before inventing new constants.
- Motion should be interruptible and short; respect `@Environment(\.accessibilityReduceMotion)`.
- Respect Reduce Transparency and Increase Contrast: prefer opacity crossfades and more solid surfaces when those settings are on.
- Notinhas pin badges and note editor should read clearly on varied screenshot backgrounds.

## Checklist

- Does the note editor still float clearly over the canvas?
- Do numbered pins remain legible at export scale?
- Does Quick Access card chrome match surrounding Notinhas panels?
- With Reduce Motion on, are transitions still understandable?

## Related

- Platform hosting → `macos-app-engineering`
- Contrast / VoiceOver → `accessibility-audit`
- Notinhas note styling → `capture-annotate-export` (when present)
