---
name: documentation
description: Documentation guidance for Notinhas — README, AGENTS.md, upstream docs/, skills routing, and MARK organization in sources.
---

# Documentation

Use when updating project docs, agent guidance, or in-source section markers.

## Ownership

- **README.md** — upstream Snapzy human docs (features, install, development). Do not rewrite as a Notinhas-only pitch unless product direction changes.
- **AGENTS.md** — canonical agent guide for Notinhas (product intent, structure, commands, fork workflow). Edit this file for agent policy.
- **docs/** — upstream Snapzy engineering docs (`CAPTURE.md`, `ANNOTATE.md`, `POST_CAPTURE.md`, etc.). Keep in sync when touching those flows; do not invent parallel root markdown backlogs for agent ops.
- **`.agents/skills/`** — reusable operational guidance per domain.
- **`.agents/SKILLS_INDEX.md`** — skill catalog and routing (when present).
- **CLAUDE.md** — optional symlink to `AGENTS.md` for tools that expect that filename; create only if tooling needs it.
- Source `// MARK:` — navigate large files (`AppStatusBarController`, `AnnotateState`, `NotinhasNoteGeometry`).

## Rules

- Keep agent policy in `AGENTS.md`; never diverge a separate `CLAUDE.md` body.
- Document Screen Recording / Accessibility requirements when capture or permission UX changes.
- Prefer linking to skills over duplicating long checklists in README.
- Do not invent script targets or test commands that do not exist under `scripts/`.

## Checklist

- Would a new contributor build and run from README + `AGENTS.md`?
- Do agent docs still match `./scripts/build_and_run.sh` and `./scripts/run-tests.sh`?
- Are deliberate fork choices (thin Notinhas module, upstream Snapzy docs) still called out?
- Does `CLAUDE.md` resolve to `AGENTS.md` if the symlink exists (`readlink CLAUDE.md`)?

## Related

- Standards / routing → `AGENTS.md` + `SKILLS_INDEX.md` + `project-standards`
- Delivery commands → `delivery-workflow`
