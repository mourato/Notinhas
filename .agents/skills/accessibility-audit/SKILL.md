---
name: accessibility-audit
description: Accessibility review for Notinhas — VoiceOver labels, permission prompts, overlay dismissal, and annotate/Notinhas controls.
---

# Accessibility Audit

Use when changing annotate UI, Notinhas note controls, permission/toast flows, or export affordances.

## Minimum Bar

- Interactive controls need useful accessibility labels.
- Color is not the only state signal (selected note, tool active, copy confirmation, empty states).
- Transient UI dismisses predictably with `Esc` where applicable (note editor overlay, modals).
- Respect Reduce Motion, Reduce Transparency, Bold Text, Increase Contrast.

## Notinhas Focus

- Note tool, editor fields, color/style controls, and side-panel list rows need action-oriented labels.
- Permission rows in onboarding/preferences should state what is blocked until granted (Screen Recording for capture; Accessibility for smart-element/scrolling paths).
- Export/copy/upload actions should announce success or failure without relying on color alone.

## Checklist

- Are new Notinhas controls reachable and labeled for VoiceOver?
- Does Esc dismiss the note editor without leaving stale focus?
- Do permission toasts explain how to grant access in System Settings?

## Related

- Platform UI → `macos-app-engineering`
- Permission debugging → `debugging-diagnostics`
- Localized strings → `localization`
