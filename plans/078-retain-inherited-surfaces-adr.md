# Plan 078: Document retained Snapzy-inherited surfaces (no feature deletion)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat a6128271..HEAD -- docs/adr/ CONTEXT.md AGENTS.md .agents/skills/capture-annotate-export/SKILL.md docs/CLOUD.md docs/CAPTURE.md README.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P3
- **Effort**: S
- **Risk**: LOW
- **Depends on**: ideally after 070–077 land so docs don’t re-mention deleted cask/discord/docker — **soft** dependency; can write ADR first with forward-looking wording
- **Category**: direction
- **Planned at**: commit `a6128271`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` after docs conflicts resolved
- **Reviewer required**: `no` (ADR review by human welcome)
- **Rationale**: Decision record + skill/docs alignment only — **no** feature deletion in this plan.
- **Escalate when**: Maintainer asks to actually gate/delete OCR, BYO cloud, or annotate toolbelt — that becomes a new implementation plan.

## Why this matters

The dead-code audit also found **direction** items: OCR/scrolling/smart-element/cutout, BYO cloud (S3/R2/Drive) vs ImgBB, and Annotate extras (watermark / integrated mockup / combine). These are **live**, not dead. Deleting them is a product call with high risk. This plan records **retain-for-now** decisions so future agents do not treat them as cleanup targets, while clarifying the core handoff loop.

## Current state

- Product intent (`AGENTS.md`): capture → pins/notes → clipboard; do not add broad recording/cloud/generic markup **unless** they support that workflow; optional Video is gated.
- `capture-annotate-export` skill: ImgBB in shipping-brief scope; reject unrelated cloud platforms growth; capture suite inherited from upstream remains in the app.
- `docs/CLOUD.md`: documents S3/R2/Google Drive + manual upload call sites; ImgBB is separate handoff upload path.
- Menu still exposes scrolling / OCR / smart element / object cutout (`AppStatusBarController`).
- Integrated mockup/watermark/combine remain in Annotate; standalone MockupManager removed by plan 075.
- `install.sh` / `uninstall.sh` remain valid GitHub Releases helpers (kept; not Homebrew).

Next ADR number: check `docs/adr/` for highest number (066 exists). Use **067+** only if free — as of planning, `docs/adr/066-absorb-counter-into-notinhas.md` exists; choose **`070`** or next free number **after listing** `ls docs/adr/` (do not collide). Prefer `docs/adr/070-retain-inherited-snapzy-surfaces.md` if 067–069 unused for ADRs (plans 067–069 are implementation plans, not ADRs).

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| List ADRs | `ls docs/adr/` | pick free NNN |
| Skill mentions | `rg -n 'Homebrew cask|local-object-storage|Discord release' .agents/skills/capture-annotate-export/SKILL.md` | no stale channel claims after edits |
| ADR exists | `test -f docs/adr/<NNN>-retain-inherited-snapzy-surfaces.md` | exit 0 |

## Scope

**In scope**:
- New ADR under `docs/adr/` recording retain decisions (below)
- Light updates to `.agents/skills/capture-annotate-export/SKILL.md` and optionally `CONTEXT.md` / `docs/CLOUD.md` / `docs/CAPTURE.md` to point at the ADR and state:
  - **Core**: area capture → Notinha pins/notes → clipboard (+ ImgBB optional)
  - **Inherited retained**: scrolling, OCR, smart element, object cutout, combine, watermark, integrated mockup mode, BYO cloud providers
  - **Removed / not product channels**: Sparkle, About/Report, Homebrew cask, Discord notify, snapzy Docker local-object-storage, standalone MockupManager
  - **Kept helpers**: `install.sh` / `uninstall.sh` (DMG convenience, not Homebrew)
- `AGENTS.md` — at most a short bullet under Product Intent or Distribution pointing at the ADR (avoid duplication)

**Out of scope**:
- Hiding menu items, compile flags, or deleting Cloud/OCR/mockup code
- Implementing Advanced gates
- Changing runtime defaults

## Decisions to record in the ADR (do not reopen in code)

1. **Capture extras** — **Retain** scrolling / OCR / smart element / object cutout / All-In-One as inherited capabilities. Do not delete in cleanup rounds. Future narrowing requires an explicit product plan.
2. **BYO cloud** — **Retain** S3/R2/Google Drive as optional manual upload. ImgBB remains the handoff-oriented link upload. Do not rip Cloud/ in dead-code passes.
3. **Annotate toolbelt** — **Retain** watermark, combine, integrated mockup mode. Standalone MockupManager window path is removed separately (plan 075). Chrome customization (plan 069) already lets users hide tools.
4. **Distribution** — Manual DMG + optional `install.sh`; **no** Homebrew cask; **no** Discord release bot.
5. **install.sh** — **Keep** as convenience; not classified as dead code.

## Git workflow

- Branch: `advisor/078-retain-inherited-surfaces-adr`
- Commit: `docs: ADR to retain inherited Snapzy surfaces out of dead-code cleanup`
- Do NOT push unless instructed.

## Steps

### Step 1: Pick ADR number

`ls docs/adr/` → choose next free numeric prefix (likely `070` if only `066` exists).

### Step 2: Write the ADR

Use the same structure as `docs/adr/066-absorb-counter-into-notinhas.md` (Status, Context, Decision, Consequences). Status: **Accepted** with today’s date. Inline the five decisions above.

**Verify**: file exists; contains “Retain” for capture extras, BYO cloud, annotate toolbelt; “no Homebrew cask”.

### Step 3: Point skill + light docs

Update `capture-annotate-export` skill with a short “Inherited surfaces (retained)” vs “Removed upstream channels” bullet list linking to the ADR.

Optional one-liner in `docs/CLOUD.md` and `docs/CAPTURE.md` linking the ADR.

**Verify**: `rg -n 'retain-inherited|070-retain|Homebrew cask' .agents/skills/capture-annotate-export/SKILL.md docs/adr` shows the ADR link and retain policy.

### Step 4: AGENTS.md micro-pointer (optional but preferred)

One sentence under Product Intent or Distribution: inherited Snapzy capture/cloud/markup surfaces are retained unless an ADR says otherwise; see `docs/adr/<NNN>-…`.

## Test plan

- None (docs/ADR only)

## Done criteria

- [ ] Accepted ADR committed with the five decisions
- [ ] capture-annotate-export skill references it
- [ ] No Swift/feature deletions in this plan’s diff
- [ ] Does not reintroduce Sparkle/Homebrew cask/Discord

## STOP conditions

- Maintainer wants **deletion/gating** of OCR or Cloud instead of retain — STOP; write a different implementation plan; do not delete here.
- ADR number collision — pick another number.

## Maintenance notes

- Future “remove OCR” / “gate cloud” work must supersede this ADR explicitly.
- Dead-code cleanups (070–077) must not contradict this ADR.
- Reviewers: ensure this plan’s diff is docs-only.
