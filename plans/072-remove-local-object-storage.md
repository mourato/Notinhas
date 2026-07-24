# Plan 072: Remove snapzy-named local object-storage Docker stack

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: `git diff --stat a6128271..HEAD -- docker-compose.local-object-storage.yml scripts/local-object-storage/ docs/CLOUD.md`
> If any in-scope file changed since this plan was written, compare the
> "Current state" excerpts against the live code before proceeding; on a
> mismatch, treat it as a STOP condition.

## Status

- **Priority**: P2
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: dx
- **Planned at**: commit `a6128271`, 2026-07-24

## Execution profile

- **Recommended profile**: `implementer-fast`
- **Risk/lane**: `Low/Fast`
- **Parallelizable**: `yes`
- **Reviewer required**: `no`
- **Rationale**: Orphan Docker harness with no docs/CI references; delete-only.
- **Escalate when**: Active Cloud S3/R2 development depends on this compose file (maintainer says so).

## Why this matters

`docker-compose.local-object-storage.yml` and `scripts/local-object-storage/` are Snapzy-named LocalStack/MinIO helpers (`snapzy-local-object-storage`, buckets `snapzy-s3-local` / `snapzy-r2-local`). Nothing in README, AGENTS, docs, or CI references them. They imply first-class local cloud DX that Notinhas does not maintain.

## Current state

- `docker-compose.local-object-storage.yml` — services/containers/buckets named `snapzy-*`
- `scripts/local-object-storage/bootstrap-localstack-s3.sh`
- `scripts/local-object-storage/bootstrap-minio-r2.sh`
- Grep of docs/README/AGENTS: **no** references (as of plan writing)
- Runtime Cloud providers (`Notinhas/Services/Cloud/`) are **live** and stay — this plan only removes the unused local Docker harness

## Commands you will need

| Purpose | Command | Expected on success |
| --- | --- | --- |
| Compose gone | `test ! -f docker-compose.local-object-storage.yml` | exit 0 |
| Scripts gone | `test ! -d scripts/local-object-storage` | exit 0 |
| Sweep | `rg -n 'local-object-storage|snapzy-local-|snapzy-s3-local|snapzy-r2-local' . --glob '!CHANGELOG.md' --glob '!plans/**'` | no matches |

## Scope

**In scope**:
- Delete `docker-compose.local-object-storage.yml`
- Delete directory `scripts/local-object-storage/` (both bootstrap scripts)
- If any doc still points at them, remove that sentence only

**Out of scope**:
- `Notinhas/Services/Cloud/**` providers, prefs, GRDB history
- ImgBB
- Adding a renamed notinhas Docker stack (do not recreate)
- Video module

## Git workflow

- Branch: `advisor/072-remove-local-object-storage`
- Commit: `chore: remove unused local object-storage Docker stack`
- Do NOT push unless instructed.

## Steps

### Step 1: Delete compose + scripts

```bash
rm -f docker-compose.local-object-storage.yml
rm -rf scripts/local-object-storage
```

**Verify**: both path checks in Commands table pass.

### Step 2: Sweep references

Run the sweep `rg` from the Commands table. Fix any remaining non-CHANGELOG references in docs/scripts if found (still in spirit of this plan — only references to the deleted harness).

**Verify**: sweep returns no matches.

## Test plan

- None. Do not run Docker. Cloud XCTests (if any) are unrelated.

## Done criteria

- [ ] Compose file and `scripts/local-object-storage/` gone
- [ ] No remaining references outside CHANGELOG/plans
- [ ] Cloud Swift sources untouched

## STOP conditions

- Maintainer needs LocalStack/MinIO for active Cloud work — STOP; optionally rename to notinhas and document under `docs/CLOUD.md` instead of deleting (report and wait).
- CI workflow references these paths — STOP (unexpected; reconcile).

## Maintenance notes

- Cloud BYO (S3/R2/Drive) remains a product-scope question (plan 078), not deleted here.
- Reviewers: ensure no accidental deletion under `Notinhas/Services/Cloud/`.
