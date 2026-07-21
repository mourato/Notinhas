---
name: code-quality
description: Refactoring and maintainability for Notinhas — deduplication, dead-code removal, and keeping the Snapzy fork coherent.
---

# Code Quality

Use when simplifying code, moving responsibilities, or cleaning unused pieces exposed by a change.

## Checklist

- Reuse an existing helper in `Snapzy/Features/Notinhas/` before adding another abstraction.
- Keep side effects localized and named clearly.
- Prefer one obvious owner for each workflow (status item, capture, annotate state, Notinhas composer, upload coordinator).
- Keep upstream Snapzy edits thin; do not rewrite Annotate wholesale for Notinhas needs.
- Remove dead UI, helpers, assets, and stale previews in the same change when they become unused.
- Support every removal with objective evidence: `rg`, call sites, or runtime path.
- Do not grow toward a multi-module split unless explicitly requested.

## Refactor Strategy

1. Identify the smallest behavior change that satisfies the request.
2. Extract only when a second call site exists or a test needs a seam.
3. Run `./scripts/run-tests.sh` (filtered to touched suites) before and after.

## Validation

```bash
./scripts/run-tests.sh
./scripts/build_and_run.sh
```

## Related

- Conventions → `swift-conventions`
- Delivery evidence → `delivery-workflow`
- Domain boundaries → `capture-annotate-export` (when present)
