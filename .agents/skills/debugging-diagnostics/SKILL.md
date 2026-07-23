---
name: debugging-diagnostics
description: Debugging guidance for Notinhas — capture permission failures, signing/TCC resets, annotate/export issues, and ImgBB upload errors.
---

# Debugging Diagnostics

Use for crashes, flaky capture/annotate, permission failures, wrong export output, or unexplained UI state.

## Method

1. Reproduce with a clear signature (action, permission state, signed vs ad-hoc build).
2. Narrow: status bar menu vs capture overlay vs Annotate canvas vs Notinhas export vs persistence vs ImgBB upload.
3. Fix with a regression note in the PR/commit; prefer a focused test when logic is pure (geometry, composer, decode).

## Notinhas Hotspots

- **Screen Recording not granted** — capture menu disabled or flows blocked (`ScreenCaptureManager`, `ScreenCaptureViewModel` / `CaptureViewModel`).
- **Accessibility not granted** — Smart Element, scrolling capture, or window resolver paths fail (`SmartElementQueryService`, `ActiveWindowResolver`).
- **Signing identity changes** — TCC grants reset; re-grant Screen Recording / Accessibility after ad-hoc resign. For local persistence checks, use `./scripts/test-tcc-local.sh` with its isolated default install path; only use `--install-path` and `--allow-system-install` when you intentionally target `/Applications`.
- **Export / clipboard** — notes panel missing from copied image; check `AnnotateExporter.composeNotinhasIfNeeded` and renderable note filter.
- **Geometry / hit-testing** — wrong pin order, move/delete not registering; check `NotinhasNoteGeometry` and `NotinhasAnnotateState`.
- **ImgBB upload** — missing API key (`notinhas.imgbb.apiKey`), network/API errors; never log key values.
- **Persistence** — corrupted annotation session JSON should fail soft; Notinhas payload on `PersistedAnnotationSession`.

## Logging Hygiene

- Prefer temporary, high-signal logs while diagnosing; do not ship noisy dumps.
- Never log full screenshots, page content, or API keys.

## Related

- AX / contrast → `accessibility-audit`
- Build/sign → `delivery-workflow`
- Domain paths → `capture-annotate-export` (when present)
