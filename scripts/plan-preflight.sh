#!/bin/bash
# Local read-only preflight checks for implementation plans.
#
# Usage:
#   ./scripts/plan-preflight.sh plans/047-local-plan-preflight.md \
#     --scope scripts/plan-preflight.sh \
#     --new-file scripts/tests/plan-preflight.sh \
#     --report build/plan-preflight/047.json --json
#
# This command inspects Git and Markdown state only. It never mutates branches,
# worktrees, remotes, or tracked files.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLAN_PATH=""
REPORT_PATH=""
JSON_OUTPUT=0
ALLOW_DIRTY=0
declare -a SCOPE_PATHS=()
declare -a NEW_FILE_PATHS=()

# check state: id|ok(0/1)|label|detail
declare -a CHECK_RECORDS=()
DEPENDENCY_RECORDS_JSON="[]"
SCOPE_RECORDS_JSON="[]"
WORKTREE_CLEAN=1
DRIFTED=0
RESULT="pass"
PLANNED_AT_SHA=""
CURRENT_HEAD=""
PLAN_EXISTS=0
DIRTY_FILES=""

usage() {
  cat <<EOF
Usage: ${SCRIPT_NAME} PLAN_PATH [options]

Read-only preflight for implementation plans under plans/. Inspects the plan
file, dependency status in plans/README.md, explicit scope paths, commit drift
since the plan's Planned at SHA, and worktree cleanliness. Never mutates Git
state, branches, worktrees, remotes, or tracked files.

Arguments:
  PLAN_PATH                 Path to a plan Markdown file (for example
                            plans/047-local-plan-preflight.md).

Options:
  --scope PATH              Path to include in scope and drift checks. The path
                            must exist unless it is also passed via --new-file.
                            Repeat for multiple paths.
  --new-file PATH           Scope path that is planned to be created by the
                            plan. Missing paths are allowed; they are still
                            included in drift checks. Repeat as needed.
  --report PATH             Write a report file to PATH (parent directories are
                            created). Prefer ignored build/ paths for reports.
  --json                    Emit machine-readable JSON (stdout when --report is
                            omitted; otherwise written to --report when the path
                            ends with .json, else appended as a JSON section).
  --allow-dirty             Do not fail when the worktree has uncommitted
                            changes; the report still lists dirty paths.
  -h, --help                Show this help and exit.

Checks performed:
  plan_valid                Plan exists with exactly one short Planned at SHA.
  dependencies_resolved     Every Depends on entry is DONE in plans/README.md.
  scope_paths               Every --scope path exists or is marked --new-file.
  drift_absent              git diff --stat <planned-at>..HEAD is empty for scope.
  worktree_clean            git status --short is empty (unless --allow-dirty).

Exit status:
  0 when all checks pass; non-zero on the first failed check category.

Examples:
  ${SCRIPT_NAME} --help
  ${SCRIPT_NAME} plans/047-local-plan-preflight.md \\
    --scope scripts/plan-preflight.sh \\
    --new-file scripts/tests/plan-preflight.sh \\
    --report build/plan-preflight/047.json --json
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

record_check() {
  local id="$1"
  local ok="$2"
  local label="$3"
  local detail="${4:-}"
  CHECK_RECORDS+=("${id}|${ok}|${label}|${detail}")
  if [[ "$ok" -eq 0 ]]; then
    RESULT="fail"
  fi
}

parse_args() {
  if [[ $# -eq 0 ]]; then
    usage
    exit 0
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --scope)
        shift
        [[ $# -gt 0 ]] || die "--scope requires a path"
        SCOPE_PATHS+=("$1")
        shift
        ;;
      --new-file)
        shift
        [[ $# -gt 0 ]] || die "--new-file requires a path"
        NEW_FILE_PATHS+=("$1")
        shift
        ;;
      --report)
        shift
        [[ $# -gt 0 ]] || die "--report requires a path"
        REPORT_PATH="$1"
        shift
        ;;
      --json)
        JSON_OUTPUT=1
        shift
        ;;
      --allow-dirty)
        ALLOW_DIRTY=1
        shift
        ;;
      --)
        shift
        break
        ;;
      -*)
        die "unknown option: $1"
        ;;
      *)
        if [[ -z "$PLAN_PATH" ]]; then
          PLAN_PATH="$1"
        else
          die "unexpected argument: $1"
        fi
        shift
        ;;
    esac
  done
}

is_new_file() {
  local candidate="$1"
  local entry
  if [[ ${#NEW_FILE_PATHS[@]} -eq 0 ]]; then
    return 1
  fi
  for entry in "${NEW_FILE_PATHS[@]}"; do
    if [[ "$entry" == "$candidate" ]]; then
      return 0
    fi
  done
  return 1
}

all_scope_paths() {
  local -a combined=()
  local entry
  if [[ ${#SCOPE_PATHS[@]} -gt 0 ]]; then
    for entry in "${SCOPE_PATHS[@]}"; do
      combined+=("$entry")
    done
  fi
  if [[ ${#NEW_FILE_PATHS[@]} -gt 0 ]]; then
    for entry in "${NEW_FILE_PATHS[@]}"; do
      local seen=0
      local existing
      if [[ ${#combined[@]} -gt 0 ]]; then
        for existing in "${combined[@]}"; do
          if [[ "$existing" == "$entry" ]]; then
            seen=1
            break
          fi
        done
      fi
      if [[ "$seen" -eq 0 ]]; then
        combined+=("$entry")
      fi
    done
  fi
  if [[ ${#combined[@]} -eq 0 ]]; then
    return 0
  fi
  printf '%s\n' "${combined[@]}"
}

normalize_depends_on() {
  local raw="$1"
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  raw="$(printf '%s' "$raw" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  case "$raw" in
    none | "—" | - | "")
      return 0
      ;;
  esac
  printf '%s' "$raw"
}

extract_plan_numbers() {
  local raw="$1"
  normalize_depends_on "$raw" >/dev/null 2>&1 || true
  local normalized
  normalized="$(normalize_depends_on "$raw")"
  if [[ -z "$normalized" ]]; then
    return 0
  fi
  printf '%s' "$normalized" | grep -Eo '[0-9]{3}' | sort -u
}

read_planned_at_sha() {
  local plan_file="$1"
  local line sha_count
  line="$(grep -E '^- \*\*Planned at\*\*:' "$plan_file" | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi
  sha_count="$(printf '%s' "$line" | grep -Eo '[0-9a-f]{7,40}' | wc -l | tr -d ' ')"
  if [[ "$sha_count" -ne 1 ]]; then
    return 1
  fi
  printf '%s' "$line" | grep -Eo '[0-9a-f]{7,40}' | head -n 1
}

read_depends_on_line() {
  local plan_file="$1"
  grep -E '^- \*\*Depends on\*\*:' "$plan_file" | head -n 1 | sed -E 's/^- \*\*Depends on\*\*:[[:space:]]*//'
}

lookup_plan_status() {
  local plan_number="$1"
  local readme="${REPO_ROOT}/plans/README.md"
  local line status
  line="$(grep -E "^\|[[:space:]]*${plan_number}[[:space:]]*\|" "$readme" | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi
  status="$(printf '%s' "$line" | awk -F'|' '{print $(NF-1)}' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
  printf '%s' "$status"
}

check_plan() {
  local plan_file="${REPO_ROOT}/${PLAN_PATH}"
  if [[ ! -f "$plan_file" ]]; then
    record_check "plan_valid" 0 "PLAN_MISSING" "plan file not found: ${PLAN_PATH}"
    return
  fi
  PLAN_EXISTS=1

  if ! PLANNED_AT_SHA="$(read_planned_at_sha "$plan_file")"; then
    record_check "plan_valid" 0 "PLAN_INVALID_SHA" "Planned at must contain exactly one short SHA"
    return
  fi

  if ! git -C "$REPO_ROOT" cat-file -e "${PLANNED_AT_SHA}^{commit}" >/dev/null 2>&1; then
    record_check "plan_valid" 0 "PLAN_INVALID_SHA" "Planned at SHA not found in repository: ${PLANNED_AT_SHA}"
    return
  fi

  record_check "plan_valid" 1 "plan_valid" "Planned at ${PLANNED_AT_SHA}"
}

check_dependencies() {
  local plan_file="${REPO_ROOT}/${PLAN_PATH}"
  local depends_raw dep dep_status dep_json="["
  local first=1
  local unresolved=0

  if [[ "$PLAN_EXISTS" -eq 0 ]]; then
    DEPENDENCY_RECORDS_JSON="[]"
    return
  fi

  depends_raw="$(read_depends_on_line "$plan_file" || true)"
  while IFS= read -r dep; do
    [[ -n "$dep" ]] || continue
    dep_status="$(lookup_plan_status "$dep" || true)"
    if [[ "$dep_status" == *DONE* ]]; then
      if [[ "$first" -eq 0 ]]; then
        dep_json+=","
      fi
      dep_json+="$(printf '{"id":"%s","status":"%s","ok":true}' "$dep" "$dep_status")"
      first=0
    else
      unresolved=1
      record_check "dependencies_resolved" 0 "DEPENDENCY_UNRESOLVED" "plan ${dep} status is not DONE (${dep_status:-missing})"
      if [[ "$first" -eq 0 ]]; then
        dep_json+=","
      fi
      dep_json+="$(printf '{"id":"%s","status":"%s","ok":false}' "$dep" "${dep_status:-missing}")"
      first=0
    fi
  done < <(extract_plan_numbers "$depends_raw")

  dep_json+="]"
  DEPENDENCY_RECORDS_JSON="$dep_json"

  if [[ "$dep_json" == "[]" ]]; then
    record_check "dependencies_resolved" 1 "dependencies_resolved" "no dependencies"
  elif [[ "$unresolved" -eq 0 ]]; then
    record_check "dependencies_resolved" 1 "dependencies_resolved" "all dependencies DONE"
  fi
}

check_scope_paths() {
  local -a scope_entries=()
  local path exists planned_new ok path_json="[" first=1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    scope_entries+=("$path")
  done < <(all_scope_paths)

  if [[ ${#scope_entries[@]} -eq 0 ]]; then
    SCOPE_RECORDS_JSON="[]"
    record_check "scope_paths" 1 "scope_paths" "no scope paths supplied"
    return
  fi

  for path in "${scope_entries[@]}"; do
    exists=0
    planned_new=0
    ok=1
    if [[ -e "${REPO_ROOT}/${path}" ]]; then
      exists=1
    elif is_new_file "$path"; then
      planned_new=1
    else
      ok=0
      record_check "scope_paths" 0 "SCOPE_MISSING" "missing scope path: ${path}"
    fi
    if [[ "$first" -eq 0 ]]; then
      path_json+=","
    fi
    path_json+="$(printf '{"path":"%s","exists":%s,"plannedNew":%s,"ok":%s}' \
      "$path" \
      "$( [[ "$exists" -eq 1 ]] && printf true || printf false )" \
      "$( [[ "$planned_new" -eq 1 ]] && printf true || printf false )" \
      "$( [[ "$ok" -eq 1 ]] && printf true || printf false )")"
    first=0
  done
  path_json+="]"
  SCOPE_RECORDS_JSON="$path_json"

  if ! printf '%s' "${CHECK_RECORDS[*]-}" | grep -q 'SCOPE_MISSING'; then
    record_check "scope_paths" 1 "scope_paths" "all scope paths satisfied"
  fi
}

check_drift() {
  local -a scope_entries=()
  local -a drift_paths=()
  local path diff_output

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    scope_entries+=("$path")
  done < <(all_scope_paths)

  if [[ -z "$PLANNED_AT_SHA" ]] || [[ ${#scope_entries[@]} -eq 0 ]]; then
    record_check "drift_absent" 1 "drift_absent" "skipped"
    return
  fi

  for path in "${scope_entries[@]}"; do
    if git -C "$REPO_ROOT" cat-file -e "${PLANNED_AT_SHA}:${path}" >/dev/null 2>&1; then
      drift_paths+=("$path")
    fi
  done

  if [[ ${#drift_paths[@]} -eq 0 ]]; then
    record_check "drift_absent" 1 "drift_absent" "no tracked scope paths at ${PLANNED_AT_SHA}"
    return
  fi

  diff_output="$(git -C "$REPO_ROOT" diff --stat "${PLANNED_AT_SHA}..HEAD" -- "${drift_paths[@]}" 2>/dev/null || true)"
  if [[ -n "$(printf '%s' "$diff_output" | sed '/^[[:space:]]*$/d')" ]]; then
    DRIFTED=1
    record_check "drift_absent" 0 "DRIFT_DETECTED" "changes since ${PLANNED_AT_SHA}"
  else
    record_check "drift_absent" 1 "drift_absent" "no drift in scope"
  fi
}

check_worktree() {
  local status_output
  status_output="$(git -C "$REPO_ROOT" status --short 2>/dev/null || true)"
  if [[ -n "$(printf '%s' "$status_output" | sed '/^[[:space:]]*$/d')" ]]; then
    WORKTREE_CLEAN=0
    DIRTY_FILES="$status_output"
    if [[ "$ALLOW_DIRTY" -eq 1 ]]; then
      record_check "worktree_clean" 1 "worktree_clean" "dirty worktree allowed"
    else
      record_check "worktree_clean" 0 "WORKTREE_DIRTY" "uncommitted changes present"
    fi
  else
    WORKTREE_CLEAN=1
    record_check "worktree_clean" 1 "worktree_clean" "worktree clean"
  fi
}

emit_text_report() {
  local record id ok label detail
  printf 'plan-preflight: %s\n' "$RESULT"
  printf 'plan: %s\n' "$PLAN_PATH"
  if [[ -n "$PLANNED_AT_SHA" ]]; then
    printf 'plannedAt: %s\n' "$PLANNED_AT_SHA"
  fi
  printf 'currentHead: %s\n' "$CURRENT_HEAD"
  printf 'worktreeClean: %s\n' "$( [[ "$WORKTREE_CLEAN" -eq 1 ]] && printf true || printf false )"
  printf 'drifted: %s\n' "$( [[ "$DRIFTED" -eq 1 ]] && printf true || printf false )"
  printf 'checks:\n'
  for record in "${CHECK_RECORDS[@]}"; do
    IFS='|' read -r id ok label detail <<<"$record"
    if [[ "$ok" -eq 1 ]]; then
      printf '  [ok] %s' "$label"
    else
      printf '  [fail] %s' "$label"
    fi
    if [[ -n "$detail" ]]; then
      printf ' — %s' "$detail"
    fi
    printf '\n'
  done
  if [[ -n "$DIRTY_FILES" ]]; then
    printf 'dirtyFiles:\n'
    printf '%s\n' "$DIRTY_FILES" | sed 's/^/  /'
  fi
}

emit_json_report() {
  local checks_file deps_file scope_file
  checks_file="$(mktemp "${TMPDIR:-/tmp}/plan-preflight-checks.XXXXXX")"
  deps_file="$(mktemp "${TMPDIR:-/tmp}/plan-preflight-deps.XXXXXX")"
  scope_file="$(mktemp "${TMPDIR:-/tmp}/plan-preflight-scope.XXXXXX")"
  printf '%s' "$DEPENDENCY_RECORDS_JSON" >"$deps_file"
  printf '%s' "$SCOPE_RECORDS_JSON" >"$scope_file"

  {
    printf '['
    local record id ok label detail first=1
    for record in "${CHECK_RECORDS[@]}"; do
      IFS='|' read -r id ok label detail <<<"$record"
      if [[ "$first" -eq 0 ]]; then
        printf ','
      fi
      python3 - "$id" "$ok" "$label" "$detail" <<'PY'
import json, sys
print(json.dumps({
    "id": sys.argv[1],
    "ok": sys.argv[2] == "1",
    "label": sys.argv[3],
    "detail": sys.argv[4],
}))
PY
      first=0
    done
    printf ']'
  } >"$checks_file"

  python3 - "$PLAN_PATH" "$PLANNED_AT_SHA" "$CURRENT_HEAD" "$WORKTREE_CLEAN" "$DRIFTED" "$RESULT" \
    "$checks_file" "$deps_file" "$scope_file" <<'PY'
import json
import sys

plan, planned_at, current_head, worktree_clean, drifted, result, checks_file, deps_file, scope_file = sys.argv[1:]
payload = {
    "plan": plan,
    "plannedAt": planned_at,
    "currentHead": current_head,
    "dependencies": json.load(open(deps_file)),
    "scope": json.load(open(scope_file)),
    "worktreeClean": worktree_clean == "1",
    "drifted": drifted == "1",
    "checks": json.load(open(checks_file)),
    "result": result,
}
print(json.dumps(payload, indent=2, sort_keys=True))
PY

  rm -f "$checks_file" "$deps_file" "$scope_file"
}

write_report() {
  local content="$1"
  local report_dir
  report_dir="$(dirname "$REPORT_PATH")"
  mkdir -p "$report_dir"
  printf '%s\n' "$content" >"$REPORT_PATH"
}

main() {
  parse_args "$@"

  [[ -n "$PLAN_PATH" ]] || die "PLAN_PATH is required"

  CURRENT_HEAD="$(git -C "$REPO_ROOT" rev-parse HEAD)"

  check_plan
  check_dependencies
  check_scope_paths
  check_drift
  check_worktree

  local text_report json_report
  text_report="$(emit_text_report)"
  json_report="$(emit_json_report)"

  if [[ -n "$REPORT_PATH" ]]; then
    if [[ "$JSON_OUTPUT" -eq 1 && "$REPORT_PATH" == *.json ]]; then
      write_report "$json_report"
    elif [[ "$JSON_OUTPUT" -eq 1 ]]; then
      write_report "${text_report}

${json_report}"
    else
      write_report "$text_report"
    fi
  fi

  if [[ "$JSON_OUTPUT" -eq 1 && -z "$REPORT_PATH" ]]; then
    printf '%s\n' "$json_report"
  elif [[ -z "$REPORT_PATH" ]]; then
    printf '%s\n' "$text_report"
  fi

  if [[ "$RESULT" == "pass" ]]; then
    exit 0
  fi
  exit 1
}

main "$@"
