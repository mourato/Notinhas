# Implementation Plans

This directory contains the improve-skill handoff plans. Plans 001–025 are
completed historical Notinhas UX/video work. The identity-separation round is
026–030 because `/plans` already had an established monotonic sequence.
Generated/reconciled on 2026-07-21 against commit `6822c42`.

## Historical plan status

| Plan | Title | Status |
|---|---|---|
| 001 | Add the Notes editor extension | DONE |
| 002 | Export a Notes composition and preference | DONE |
| 003 | Upload Notinhas output to Imgur | SUPERSEDED — shipped as ImgBB |
| 004 | Draw Notinhas pin numerals upright | DONE |
| 005 | Make exported Notes panel text readable on light background | DONE |
| 006 | Move and delete Notinhas pins while Note is active | DONE |
| 007 | Redesign note editor modal with live style updates | DONE |
| 008 | Show export-parity composition in Preview | DONE |
| 009 | Per-note Notinhas pin size | DONE |
| 010 | Rebase existing agent skills | DONE |
| 011 | Add `capture-annotate-export` skill | DONE |
| 012 | Port `project-standards` skill | DONE |
| 013 | ImgBB upload feedback lifecycle | DONE |
| 014 | Guard ImgBB button without API key | DONE |
| 015 | Keyboard-shortcut hints | DONE — superseded by 019 |
| 016 | Note-tool discoverability tooltip | DONE — superseded by 018 |
| 017 | Arc-like overlay-tooltip component | DONE |
| 018 | Note-tool overlay tooltip | DONE |
| 019 | Note-editor footer overlay tooltips | DONE |
| 020 | Optional Video module gate/build affordances | DONE |
| 021 | Gate app-shell Video entry points | DONE |
| 022 | Hide Video Preferences when disabled | DONE |
| 023 | Gate History/Quick Access/Onboarding for Video | DONE |
| 024 | Compile-time isolation of Recording/VideoEditor | DONE |
| 025 | Document Video workflow and dual-mode verification | DONE |

## Identity-separation execution order

| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 026 | Migrate Snapzy data into Notinhas storage | P1 | L | — | DONE (`ba3a2f6`, review fixes `d2c1b57`; full suite has two pre-existing flaky failures) |
| 027 | Remove Sparkle, Report a Problem, and About | P1 | L | 026 | DONE (`db1c0a0`, review fixes `92491f3`; full suite has two pre-existing flaky failures) |
| 028 | Replace `snapzy://` with `notinhas://` | P1 | M | 027 | DONE (`1507d08`; full suite has two pre-existing flaky failures) |
| 029 | Rename the technical product identity to Notinhas | P1 | L | 026–028 | DONE (`6124d74`, review fixes `163e0f1`; focused migration tests and Debug build pass) |
| 030 | Complete documentation and final validation | P2 | L | 029 | DONE (`39f7053`, review fixes `5bc63c6`; docs/scripts residue fixed; default/video suites retain two pre-existing UI failures and Release validation remains environment-blocked) |

Status values: `TODO` | `IN PROGRESS` | `DONE` | `BLOCKED (reason)` |
| `REJECTED (rationale)` | `SUPERSEDED (replacement)`.

## Confirmed product decisions

- Product identity becomes Notinhas, including technical identity where safe.
- Release/debug bundle IDs become `com.mourato.notinhas` and
  `com.mourato.notinhas.debug`.
- Existing data/configuration migrates automatically before database setup.
- Only `notinhas://` is registered/accepted; `snapzy://` is rejected.
- Sparkle, automatic updates, Report a Problem, and About are removed.
- GitHub Releases/DMGs remain manual; cloud, recording, video, and local
  diagnostics remain.
- Screen Recording, Accessibility, and Microphone permissions must be granted
  again after the bundle-ID change because TCC grants cannot be copied.

## Required executor/reviewer loop

Every plan requires:

1. A Composer 2.5 executor in an isolated worktree implements only the plan,
   runs every gate, commits, merges, removes its worktree/branch, and pushes.
   If isolation prevents integration, GPT 5.6 performs merge, cleanup, and push
   from the returned commit.
2. GPT 5.6 runs `/thermo-nuclear-code-quality-review` on the integrated diff.
3. GPT 5.6 fixes every finding, reruns relevant gates, commits the fixes, and
   starts the next plan only after that reviewed commit is integrated.

No executor may silently skip a gate, widen scope, delete legacy data, or
replace a STOP condition with an assumption.

## Dependency notes

- 026 must land before the bundle-ID/path cutover.
- 027 removes shared Sparkle/preferences/release surfaces before URL and
  physical-renaming work; legacy `[updates]` TOML remains importable.
- 028 owns the external URL contract and explicitly rejects the old scheme.
- 029 performs the physical Xcode/module/bundle rename after runtime contracts
  are stable.
- 030 updates public/agent documentation and performs final build, residue,
  migration, permission, and capture → annotate → clipboard validation.

## Compatibility allowlist

Any remaining Snapzy reference after Plan 030 must be classified as one of:

- legacy migration path or old bundle ID;
- old UserDefaults/TOML/sidecar/credential-archive input;
- external cloud object namespace that must remain readable;
- intentional `snapzy://` rejection test;
- historical content explicitly retained for compatibility.

Active UI, runtime identity, installer defaults, public docs, and agent
instructions may not use this allowlist to retain branding.

## Findings considered and rejected

- Removing cloud, recording, or video: rejected; the user chose identity and
  upstream-integration separation while preserving existing features.
- Keeping `snapzy://` as an alias: rejected by explicit decision.
- Replacing Sparkle with another updater: rejected; distribution is manual.
- Removing local diagnostics with Report a Problem: rejected; local diagnostics
  remain useful without an upload/support flow.
- Renaming external cloud object prefixes: rejected as unsafe for user data.
- Publishing these plans as GitHub issues: not requested; no issues were created.
