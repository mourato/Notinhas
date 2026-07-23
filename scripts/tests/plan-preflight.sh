#!/bin/bash
# Fixture tests for scripts/plan-preflight.sh (isolated temporary Git repos).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREFLIGHT="${ROOT_DIR}/scripts/plan-preflight.sh"

TESTS_RUN=0
TESTS_PASSED=0
FAILURES=()

pass() {
  TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
  local name="$1"
  local detail="$2"
  FAILURES+=("${name}: ${detail}")
  printf 'FAIL: %s — %s\n' "$name" "$detail" >&2
}

assert_exit() {
  local name="$1"
  local expected="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  set +e
  "$@" >/dev/null 2>&1
  local actual=$?
  set -e
  if [[ "$actual" -eq "$expected" ]]; then
    pass
    printf 'ok  %s (exit %s)\n' "$name" "$actual"
  else
    fail "$name" "expected exit ${expected}, got ${actual}"
  fi
}

assert_output_contains() {
  local name="$1"
  local needle="$2"
  shift 2
  TESTS_RUN=$((TESTS_RUN + 1))
  local output
  set +e
  output="$("$@" 2>&1)"
  local status=$?
  set -e
  if printf '%s' "$output" | grep -Fq "$needle"; then
    pass
    printf 'ok  %s (found %s)\n' "$name" "$needle"
  else
    fail "$name" "output missing ${needle} (exit ${status})"
  fi
}

write_readme() {
  local root="$1"
  mkdir -p "${root}/plans"
  cat >"${root}/plans/README.md" <<'EOF'
| Plan | Title | Priority | Effort | Depends on | Status |
|---|---|---:|---:|---|---|
| 001 | Example done plan | P1 | S | — | DONE |
| 048 | Blocked dependency | P1 | M | 047 | TODO |
EOF
}

write_plan() {
  local root="$1"
  local filename="$2"
  local depends="$3"
  local planned_sha="$4"
  cat >"${root}/plans/${filename}" <<EOF
# Plan fixture

- **Depends on**: ${depends}
- **Planned at**: commit \`${planned_sha}\`, 2026-07-23
EOF
}

install_preflight() {
  local repo="$1"
  mkdir -p "${repo}/scripts"
  cp "$PREFLIGHT" "${repo}/scripts/plan-preflight.sh"
  chmod +x "${repo}/scripts/plan-preflight.sh"
}

run_preflight() {
  local repo="$1"
  shift
  (
    cd "$repo"
    ./scripts/plan-preflight.sh "$@"
  )
}

setup_repo() {
  local tmp
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/plan-preflight-fixture.XXXXXX")"
  (
    cd "$tmp"
    git init -q
    git config user.email "fixture@example.com"
    git config user.name "Fixture"
    mkdir -p scripts plans
    echo "stable" >scripts/existing.sh
    write_readme "$tmp"
    git add .
    git commit -q -m "base"
    local planned_sha
    planned_sha="$(git rev-parse HEAD)"
    write_plan "$tmp" "valid.md" "none" "$planned_sha"
    git add plans/valid.md
    git commit -q -m "add plan"
  )
  install_preflight "$tmp"
  git -C "$tmp" add scripts/plan-preflight.sh
  git -C "$tmp" commit -q -m "add preflight command"
  printf '%s' "$tmp"
}

main() {
  [[ -x "$PREFLIGHT" ]] || chmod +x "$PREFLIGHT"
  bash -n "$PREFLIGHT"

  assert_exit "help exits zero" 0 "$PREFLIGHT" --help

  local repo
  repo="$(setup_repo)"

  assert_exit "missing plan fails" 1 run_preflight "$repo" plans/missing.md --scope scripts/existing.sh
  assert_output_contains "missing plan label" "PLAN_MISSING" \
    run_preflight "$repo" plans/missing.md --scope scripts/existing.sh

  cat >"${repo}/plans/bad-sha.md" <<'EOF'
# Plan fixture

- **Depends on**: none
- **Planned at**: commit `aaaaaaa` and `bbbbbbb`, 2026-07-23
EOF
  git -C "$repo" add plans/bad-sha.md
  git -C "$repo" commit -q -m "bad sha fixture"

  assert_exit "malformed planned sha fails" 1 \
    run_preflight "$repo" plans/bad-sha.md --scope scripts/existing.sh
  assert_output_contains "malformed sha label" "PLAN_INVALID_SHA" \
    run_preflight "$repo" plans/bad-sha.md --scope scripts/existing.sh

  local planned_sha
  planned_sha="$(git -C "$repo" rev-list --max-parents=0 HEAD)"
  write_plan "$repo" "blocked-dep.md" "048" "$planned_sha"
  git -C "$repo" add plans/blocked-dep.md
  git -C "$repo" commit -q -m "blocked dependency fixture"

  assert_exit "unresolved dependency fails" 1 \
    run_preflight "$repo" plans/blocked-dep.md --scope scripts/existing.sh
  assert_output_contains "dependency label" "DEPENDENCY_UNRESOLVED" \
    run_preflight "$repo" plans/blocked-dep.md --scope scripts/existing.sh

  assert_exit "missing scope path fails" 1 \
    run_preflight "$repo" plans/valid.md --scope scripts/missing.sh
  assert_output_contains "scope missing label" "SCOPE_MISSING" \
    run_preflight "$repo" plans/valid.md --scope scripts/missing.sh

  assert_exit "planned new file passes scope" 0 \
    run_preflight "$repo" plans/valid.md --new-file scripts/new.sh
  assert_output_contains "planned new file in json" '"plannedNew": true' \
    run_preflight "$repo" plans/valid.md --new-file scripts/new.sh --json

  echo "drift" >>"${repo}/scripts/existing.sh"
  git -C "$repo" add scripts/existing.sh
  git -C "$repo" commit -q -m "drift"
  assert_exit "drift fails" 1 \
    run_preflight "$repo" plans/valid.md --scope scripts/existing.sh
  assert_output_contains "drift label" "DRIFT_DETECTED" \
    run_preflight "$repo" plans/valid.md --scope scripts/existing.sh

  git -C "$repo" checkout -q HEAD~1
  printf 'dirty\n' >"${repo}/scratch.txt"
  assert_exit "dirty worktree fails" 1 \
    run_preflight "$repo" plans/valid.md --scope scripts/existing.sh
  assert_output_contains "dirty label" "WORKTREE_DIRTY" \
    run_preflight "$repo" plans/valid.md --scope scripts/existing.sh

  assert_exit "allow dirty passes" 0 \
    run_preflight "$repo" plans/valid.md --scope scripts/existing.sh --allow-dirty
  assert_output_contains "allow dirty lists dirty files" "dirtyFiles" \
    run_preflight "$repo" plans/valid.md --scope scripts/existing.sh --allow-dirty

  local report="${repo}/build/plan-preflight/report.json"
  assert_exit "valid plan passes" 0 \
    run_preflight "$repo" plans/valid.md --scope scripts/existing.sh --allow-dirty --json --report "$report"
  python3 -m json.tool "$report" >/dev/null
  assert_output_contains "json result pass" '"result": "pass"' \
    python3 -m json.tool "$report"

  assert_output_contains "text output contract" "plan-preflight:" \
    run_preflight "$repo" plans/valid.md --scope scripts/existing.sh --allow-dirty

  rm -rf "$repo"

  printf '\nplan-preflight fixtures: %s/%s passed\n' "$TESTS_PASSED" "$TESTS_RUN"
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    printf 'failures:\n' >&2
    printf '  - %s\n' "${FAILURES[@]}" >&2
    exit 1
  fi
}

main "$@"
