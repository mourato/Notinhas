# Plan 070: Remove Homebrew cask and release CI cask updates

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat a6128271..HEAD -- Casks/ .github/workflows/release-publish.yml Notinhas/Services/AppIdentity/AppIdentityManager.swift docs/APP_LIFECYCLE.md docs/RELEASES.md README.md AGENTS.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `a6128271`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes` — distribution cleanup workstream (independent of 075 Swift mockup)
- **Reviewer required**: `no` — deterministic delete + CI/doc edits; thermo optional
- **Rationale**: File deletes and sed-step removal with grep-based done criteria; no app runtime behavior change.
- **Escalate when**: Someone still publishes a Homebrew tap from this repo, or `release-publish.yml` structure drifted so step numbers/names no longer match.

## Why this matters

Notinhas ships via manual GitHub Releases (`Notinhas-v<version>.dmg`). Product policy (`AGENTS.md`) forbids treating Homebrew as a product channel. The repo still has `Casks/notinhas.rb` (wrong org `duongductrong/Notinhas`) and `release-publish.yml` still sed-updates that cask and commits to `main` after every stable release. Removing this stops false distribution surface and a stale/wrong-org auto-commit path.

## Current state

- `Casks/notinhas.rb` — Homebrew cask; `url`/`homepage` point at `https://github.com/duongductrong/Notinhas` (not `mourato/Notinhas`).
- `.github/workflows/release-publish.yml` lines ~421–446 — after creating the GitHub Release on stable tags:
  - sed-updates `version` / `sha256` in `Casks/notinhas.rb`
  - sed-rewrites `/Notinhas/v…/install.sh` in README (current README uses `main/install.sh` — sed is a no-op)
  - `git add Casks/notinhas.rb README.md` and push commit
- `README.md` Install section documents DMG + `install.sh` only — **no** `brew install` path.
- `AGENTS.md` Distribution: manual GitHub Releases; no Sparkle.
- `AppIdentityManager.swift:84-90` and `docs/APP_LIFECYCLE.md:120` still explain quarantine false-positives in terms of “Homebrew Cask upgrades” — keep the quarantine logic; soften wording so it does not imply Notinhas ships a cask.
- **Keep** `brew install create-dmg` / `brew install swiftformat` / ImageMagick — those are **dev/CI tooling**, not the app cask.

Excerpt — cask header:

```1:8:Casks/notinhas.rb
cask "notinhas" do
  version "1.29.1"
  sha256 "d761801001fe579144f4866f9413ba32c75d1a5dc94011f9b84ced1824f5a88c"

  url "https://github.com/duongductrong/Notinhas/releases/download/v#{version}/Notinhas-v#{version}.dmg"
  name "Notinhas"
  desc "Native macOS screenshots, recording, annotation, and editing from the menu bar"
  homepage "https://github.com/duongductrong/Notinhas"
```

Excerpt — release workflow (stable-only block):

```421:446:.github/workflows/release-publish.yml
      # Homebrew cask and README track stable releases only — skipped for beta
      - name: Update Homebrew cask
        if: steps.version.outputs.is_beta != 'true'
        run: |
          VERSION="${{ steps.version.outputs.version }}"
          SHA="${{ steps.sha256.outputs.sha256 }}"
          sed -i '' "s/version \".*\"/version \"${VERSION}\"/" Casks/notinhas.rb
          sed -i '' "s/sha256 \".*\"/sha256 \"${SHA}\"/" Casks/notinhas.rb

      - name: Update README install version
        if: steps.version.outputs.is_beta != 'true'
        run: |
          VERSION="${{ steps.version.outputs.version }}"
          sed -i '' "s|/Notinhas/v[0-9][0-9.]*\/install.sh|/Notinhas/v${VERSION}/install.sh|g" README.md

      - name: Commit cask and readme update
        run: |
          ...
          git add Casks/notinhas.rb README.md
          ...
          git commit -m "chore: update cask and readme for v${{ steps.version.outputs.version }}"
          git push origin main
```

Conventions: Conventional Commits (`chore:`, `docs:`). Match recent `git log` style.

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Drift check | `git diff --stat a6128271..HEAD -- Casks/ .github/workflows/release-publish.yml Notinhas/Services/AppIdentity/AppIdentityManager.swift docs/APP_LIFECYCLE.md` | empty or review drift |
| Confirm no cask left | `test ! -e Casks/notinhas.rb && test ! -d Casks` | exit 0 |
| Confirm CI gone | `rg -n 'Homebrew cask|Casks/notinhas|Update README install version' .github/workflows/release-publish.yml` | no matches |
| Keep create-dmg brew | `rg -n 'brew install create-dmg' .github/workflows/release-publish.yml` | ≥1 match |
| YAML sanity | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release-publish.yml'))"` | exit 0 (if PyYAML available; else skip and rely on structure review) |

## Suggested executor toolkit

- Skills: `delivery-workflow` (+ overlay), `project-standards`, `documentation` if editing AGENTS/docs wording.
- Do **not** remove `install.sh` in this plan (kept on purpose; see plan 078).

## Scope

**In scope**:
- Delete `Casks/notinhas.rb` and remove empty `Casks/` directory
- `.github/workflows/release-publish.yml` — remove the three steps: Update Homebrew cask, Update README install version, Commit cask and readme update (and the Homebrew comment block)
- `Notinhas/Services/AppIdentity/AppIdentityManager.swift` — rewrite quarantine comment to describe Gatekeeper/`mv`/`cp` preserving xattr **without** implying a Notinhas Homebrew cask channel
- `docs/APP_LIFECYCLE.md` — same comment softening on the quarantine bullet
- `docs/RELEASES.md` — if it mentions Homebrew cask updates, remove that; keep Discord mention for plan 071 to own
- `plans/README.md` — status row only if instructed

**Out of scope**:
- `install.sh` / `uninstall.sh` / README curl install section
- `brew install create-dmg` / swiftformat / imagemagick tooling
- Discord `release-notify.yml` (plan 071)
- Sparkle (already removed)
- Any Swift behavior change beyond comments

## Git workflow

- Branch: `advisor/070-remove-homebrew-cask`
- Commit message example: `chore: remove Homebrew cask and release cask updates`
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Delete the cask

Remove `Casks/notinhas.rb` and the `Casks/` directory if empty.

**Verify**: `test ! -e Casks/notinhas.rb && test ! -d Casks` → exit 0

### Step 2: Strip cask + dead README sed from release-publish

In `.github/workflows/release-publish.yml`, delete the entire block from the comment `# Homebrew cask and README…` through the `Commit cask and readme update` step (inclusive), so the job ends after Create GitHub Release / artifact upload as appropriate.

Do **not** delete earlier steps that run `brew install create-dmg`.

**Verify**:
```bash
rg -n 'Casks/notinhas|Update Homebrew cask|Update README install version|chore: update cask and readme' .github/workflows/release-publish.yml
```
→ no matches

```bash
rg -n 'brew install create-dmg' .github/workflows/release-publish.yml
```
→ at least one match

### Step 3: Soften Homebrew-as-channel comments

In `AppIdentityManager.swift`, replace the comment that names “Homebrew Cask upgrades (`brew upgrade`)” with wording that CLI/file-manager copies into Applications can preserve quarantine xattr, and Gatekeeper clears it on first launch for notarized apps — **without** saying Notinhas is distributed via Homebrew.

In `docs/APP_LIFECYCLE.md`, update the matching quarantine bullet the same way.

**Verify**:
```bash
rg -n 'Homebrew Cask|brew upgrade' Notinhas/Services/AppIdentity/AppIdentityManager.swift docs/APP_LIFECYCLE.md
```
→ no matches (tooling brew mentions elsewhere OK)

### Step 4: Docs sweep for cask channel

```bash
rg -n 'Casks/|brew install notinhas|homebrew cask|Homebrew cask' README.md docs AGENTS.md CONTRIBUTING.md --glob '*.md'
```
→ no product-cask references (create-dmg/swiftformat brew OK). Fix any leftover product-cask docs in scope files.

**Verify**: same `rg` → clean for product cask phrases above.

## Test plan

- No new XCTest required (CI/docs only).
- Manual: read the edited `release-publish.yml` end of job and confirm Create GitHub Release remains and no push-to-main cask commit remains.

## Done criteria

- [ ] `Casks/` directory gone
- [ ] No Homebrew cask update / README install sed / cask commit steps in `release-publish.yml`
- [ ] `brew install create-dmg` (or equivalent DMG tooling) still present in release workflow
- [ ] Quarantine comments no longer imply Notinhas Homebrew distribution
- [ ] `rg -n 'Casks/notinhas' .` returns no matches outside `plans/` and `CHANGELOG.md` history (CHANGELOG historical lines may remain — do not rewrite CHANGELOG in this plan)
- [ ] No files outside in-scope list modified

## STOP conditions

- `release-publish.yml` no longer contains the named steps (already removed) — mark DONE / REJECTED and report.
- Removing the commit step would also remove unrelated required pushes — STOP and report.
- Product owner asks to **keep** Homebrew — STOP; do not delete.

## Maintenance notes

- Future agents must not re-add `Casks/` without an explicit product decision reversing AGENTS.md.
- Reviewers: confirm wrong-org URL is gone and create-dmg brew remains.
- Deferred: `install.sh` convenience path (plan 078 documents keep).
