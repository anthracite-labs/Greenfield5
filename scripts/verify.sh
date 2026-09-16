#!/usr/bin/env bash
# App-Factory foundation verification gate.
#
# The authoritative quality gate for this repository. Deterministic, committed,
# and re-run independently by .github/workflows/verify.yml. Exits non-zero when
# any required check fails.
#
# Usage:
#   scripts/verify.sh                     run every check
#   scripts/verify.sh --list              list check names and exit
#   scripts/verify.sh --only=NAME         run one check (repeatable)
#   scripts/verify.sh --skip-agentshield  skip the scanner (offline)
#   scripts/verify.sh --require-agentshield  fail if the scanner cannot run
#   scripts/verify.sh --quiet             only failures and the summary
#
# Environment:
#   VERIFY_AGENTSHIELD=auto|off|require   default: auto
#
# Lifecycle note: whether application-stack artifacts are allowed is NOT a
# constant in this script. It is committed repository state in
# config/project.env, validated by check_lifecycle and consumed by
# check_no_app_stack, so a project can graduate to an application stack through
# a reviewed config diff instead of an edit to the gate.
#
# Design note: .git/hooks/ is deliberately NOT used for enforcement — hooks are
# not committed, so a fresh clone (every new Arena session) has none.
# See docs/decisions/0002-verification-gate.md.

# Lint note: SC2329 ("function never invoked") and SC2317 ("command appears to
# be unreachable") are suppressed file-wide because the check_* functions are
# dispatched by constructed name ("check_${check}") in the run loop at the
# bottom, so the linter cannot see their call sites. Which of the two codes is
# reported depends on the shellcheck version (0.11 reports SC2329 at the
# definition; 0.9 reports SC2317 on every line inside), so both are listed to
# keep the gate stable across local and CI toolchains.
# Every other finding, down to style severity, must still be clean.
# shellcheck disable=SC2317,SC2329

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$REPO_ROOT" || exit 2

PROJECT_CONFIG="config/project.env"

# --- State -------------------------------------------------------------------
declare -a CHECK_ORDER=()
declare -a SELECTED=()
declare -a FAILURE_MESSAGES=()
PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
QUIET=0
AGENTSHIELD_MODE="${VERIFY_AGENTSHIELD:-auto}"
LIST_ONLY=0

# --- Output helpers ----------------------------------------------------------
c_reset='' c_pass='' c_fail='' c_skip='' c_dim=''
if [ -t 1 ]; then
  c_reset=$'\033[0m'; c_pass=$'\033[32m'; c_fail=$'\033[31m'
  c_skip=$'\033[33m'; c_dim=$'\033[2m'
fi

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

report_pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf '  %s[PASS]%s %-18s %s\n' "$c_pass" "$c_reset" "$1" "$2"
}

report_fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  FAILURE_MESSAGES+=("$1: $2")
  printf '  %s[FAIL]%s %-18s %s\n' "$c_fail" "$c_reset" "$1" "$2"
}

report_skip() {
  SKIP_COUNT=$((SKIP_COUNT + 1))
  printf '  %s[SKIP]%s %-18s %s\n' "$c_skip" "$c_reset" "$1" "$2"
}

fail_lines() {
  local name="$1"; shift
  local detail="$1"; shift
  local line
  report_fail "$name" "$detail"
  for line in "$@"; do
    printf '         %s%s%s\n' "$c_dim" "$line" "$c_reset"
  done
}

# --- Utilities ---------------------------------------------------------------
# File discovery walks the WORKING TREE, not the git index, so the gate also
# covers a fresh session's uncommitted work. Only the executable-bit check
# consults the index, and only for files that are already tracked.
md_files() {
  find . -type f \( -name '*.md' -o -name '*.MD' \) -not -path './.git/*' |
    sed 's|^\./||' | LC_ALL=C sort
}

shell_files() {
  find . -type f -name '*.sh' -not -path './.git/*' |
    sed 's|^\./||' | LC_ALL=C sort
}

ecc_files() {
  find "$@" -maxdepth 1 -type f -name '*.md' 2>/dev/null |
    sed 's|^\./||' | LC_ALL=C sort
}

workflow_files() {
  find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) 2>/dev/null |
    sed 's|^\./||' | LC_ALL=C sort
}

version_value() {
  local key="$1"
  sed -n "s/^${key}=//p" .ecc/VERSION 2>/dev/null | head -n 1
}

# config_value reads one key from config/project.env. The file is parsed
# line-by-line and never sourced, so a malformed or hostile value cannot be
# executed by the gate that is supposed to be inspecting it.
config_value() {
  local key="$1"
  [ -f "$PROJECT_CONFIG" ] || return 0
  sed -n "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*//p" "$PROJECT_CONFIG" |
    head -n 1 | sed 's/[[:space:]]*$//'
}

# config_key_count counts how many times a key is assigned. Duplicate
# assignments make committed lifecycle state ambiguous: config_value silently
# takes the first, a human reading the file usually takes the last.
#
# Implementation note: `grep -c` PRINTS 0 and EXITS 1 when nothing matches, so
# `grep -c ... || printf '0'` emits "0\n0" and every later numeric test on the
# result is a syntax error that silently evaluates false. That bug let a
# missing required key pass the cardinality check entirely. Counting lines here
# instead keeps the output a single integer on every path.
config_key_count() {
  local key="$1"
  if [ ! -f "$PROJECT_CONFIG" ]; then
    printf '0'
    return 0
  fi
  # shellcheck disable=SC2126  # `grep -c` is exactly the bug described above:
  # it exits 1 on no match, which corrupted the count. Keep grep | wc -l.
  grep -E "^[[:space:]]*${key}[[:space:]]*=" "$PROJECT_CONFIG" 2>/dev/null |
    wc -l | tr -d '[:space:]'
}

# The marker that makes an ADR machine-identifiable as the record of an
# application-stack decision. A stack ADR must carry BOTH this line and an
# accepted status; existing on disk is not enough.
STACK_ADR_MARKER='**Decision Type:** application-stack'
STACK_ADR_STATUS='**Status:** accepted'

# adr_has_metadata_line answers: does $1 contain $2 as a REAL metadata line?
#
# Substring matching is not sufficient here and was a live bypass: the ADR
# template carries the marker inside an instructional <!-- --> comment, so
# copying the template to another filename and flipping only the status made a
# completely unrelated ADR satisfy both checks. Two rules close that:
#
#   1. HTML comment regions are stripped before matching, so instructional or
#      example text can never satisfy a requirement.
#   2. The match must be a whole line (after trimming surrounding whitespace),
#      not a substring, so prose that merely mentions the marker is not enough.
#
# Fenced code blocks are stripped too: a documented example of a stack ADR
# should not turn the document quoting it into one.
adr_has_metadata_line() {
  local file="$1" wanted="$2"
  [ -f "$file" ] || return 1
  awk -v want="$wanted" '
    BEGIN { found = 0; in_comment = 0; in_fence = 0 }
    {
      line = $0

      # Strip complete <!-- ... --> spans that open and close on this line.
      while (match(line, /<!--.*-->/)) {
        line = substr(line, 1, RSTART - 1) substr(line, RSTART + RLENGTH)
      }

      # Handle multi-line comment regions.
      if (in_comment) {
        idx = index(line, "-->")
        if (idx == 0) { next }
        line = substr(line, idx + 3)
        in_comment = 0
      }
      idx = index(line, "<!--")
      if (idx > 0) {
        line = substr(line, 1, idx - 1)
        in_comment = 1
      }

      # Skip fenced code blocks.
      probe = line
      sub(/^[[:space:]]+/, "", probe)
      if (probe ~ /^(```|~~~)/) { in_fence = !in_fence; next }
      if (in_fence) { next }

      # Whole-line match, ignoring surrounding whitespace.
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line == want) { found = 1 }
    }
    END { exit(found ? 0 : 1) }
  ' "$file"
}

# validate_stack_transition is the single source of truth for "may the
# foundation no-stack guard stand down?". It is shared by check_lifecycle and
# check_no_app_stack so that running either one alone - including
# `verify.sh --only=no_app_stack` - reaches the same verdict. Duplicating this
# logic, or letting one check trust that another already ran, is exactly how a
# standalone invocation ends up standing the guard down on an invalid state.
#
# Appends human-readable reasons to the caller's array named by $1.
# Returns 0 when the transition is valid, 1 otherwise.
validate_stack_transition() {
  local -n _problems="$1"
  local phase allow adr
  phase="$(config_value PROJECT_PHASE)"
  allow="$(config_value ALLOW_APP_STACK)"
  adr="$(config_value STACK_DECISION_ADR)"

  [ "$allow" = "1" ] || return 1

  local ok=0

  # Ambiguous state must never authorise a transition. config_value takes the
  # FIRST assignment, so a valid first value followed by a conflicting
  # duplicate would otherwise let the standalone guard stand down on a config
  # the full gate rejects. Cardinality is therefore enforced here, in the
  # shared path, not only in check_lifecycle.
  local tkey tcount
  for tkey in PROJECT_PHASE ALLOW_APP_STACK STACK_DECISION_ADR; do
    tcount="$(config_key_count "$tkey")"
    if [ "$tcount" -ne 1 ]; then
      _problems+=("${tkey} must be assigned exactly once to authorise a transition, found ${tcount}")
      ok=1
    fi
  done

  if [ "$phase" != "implementation" ]; then
    _problems+=("ALLOW_APP_STACK=1 requires PROJECT_PHASE=implementation, got: ${phase:-<empty>}")
    ok=1
  fi

  if [ -z "$adr" ]; then
    _problems+=("ALLOW_APP_STACK=1 requires STACK_DECISION_ADR to name the ADR that records the stack choice")
    return 1
  fi

  case "$adr" in
    docs/decisions/*.md) : ;;
    *)
      _problems+=("STACK_DECISION_ADR must be a path under docs/decisions/ ending in .md, got: $adr")
      return 1
      ;;
  esac

  # The ADR template is a fill-in-the-blanks skeleton, never a decision.
  case "$(basename -- "$adr")" in
    0000-template.md)
      _problems+=("STACK_DECISION_ADR points at the ADR template, which records no decision: $adr")
      return 1
      ;;
  esac

  if [ ! -f "$adr" ]; then
    _problems+=("STACK_DECISION_ADR points at a file that does not exist: $adr")
    return 1
  fi

  # Existence is not approval, and an arbitrary foundation ADR is not a stack
  # decision. Both markers must appear as real metadata lines - not inside an
  # HTML comment, not inside a code fence, and not as a substring of prose.
  if ! adr_has_metadata_line "$adr" "$STACK_ADR_MARKER"; then
    _problems+=("$adr has no active stack-decision marker (expected the standalone line: ${STACK_ADR_MARKER})")
    ok=1
  fi
  if ! adr_has_metadata_line "$adr" "$STACK_ADR_STATUS"; then
    _problems+=("$adr is not accepted (expected the standalone line: ${STACK_ADR_STATUS})")
    ok=1
  fi

  return "$ok"
}

selected() {
  local name="$1"
  [ "${#SELECTED[@]}" -eq 0 ] && return 0
  local want
  for want in "${SELECTED[@]}"; do
    [ "$want" = "$name" ] && return 0
  done
  return 1
}

# Registers a check in run order.
register() { CHECK_ORDER+=("$1"); }

# --- Required foundation files ----------------------------------------------
REQUIRED_FILES=(
  AGENTS.md
  README.md
  FOUNDATION_VERSION
  .ecc/BOOTSTRAP.md
  .ecc/VERSION
  .ecc/UPSTREAM.md
  .ecc/LICENSE-ECC
  .ecc/rules/engineering.md
  .ecc/rules/security.md
  .ecc/rules/testing.md
  .ecc/rules/git.md
  .ecc/skills/INDEX.md
  .ecc/skills/planning.md
  .ecc/skills/research.md
  .ecc/skills/tdd.md
  .ecc/skills/debugging.md
  .ecc/skills/code-review.md
  .ecc/skills/spec-review.md
  .ecc/skills/security-review.md
  .ecc/skills/verification.md
  .ecc/skills/project-memory.md
  .ecc/skills/decisions.md
  .ecc/roles/architect.md
  .ecc/roles/security-reviewer.md
  .ecc/roles/spec-reviewer.md
  config/project.env
  config/main-ruleset.json
  docs/PRODUCT.md
  docs/ARCHITECTURE.md
  docs/ARENA.md
  docs/DOMAIN.md
  docs/ROADMAP.md
  docs/SECURITY.md
  docs/MEMORY.md
  docs/FACTORY.md
  docs/decisions/README.md
  docs/decisions/0000-template.md
  docs/codemaps/README.md
  scripts/bootstrap.sh
  scripts/init-project.sh
  scripts/verify.sh
  scripts/sync-ecc.sh
  scripts/selftest.sh
  .github/workflows/verify.yml
  .github/PULL_REQUEST_TEMPLATE.md
)

REQUIRED_EXECUTABLES=(
  scripts/bootstrap.sh
  scripts/init-project.sh
  scripts/verify.sh
  scripts/sync-ecc.sh
  scripts/selftest.sh
)

# The CI job names the branch ruleset requires as status contexts. Renaming a
# job without updating config/main-ruleset.json would silently unprotect the
# default branch, so the two are cross-checked here.
REQUIRED_CI_CONTEXTS=(
  'Foundation gate'
  'Independent checks'
)

# --- 1. foundation -----------------------------------------------------------
check_foundation() {
  local name="foundation"
  selected "$name" || return 0
  local missing=() f
  for f in "${REQUIRED_FILES[@]}"; do
    [ -f "$f" ] || missing+=("$f")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    fail_lines "$name" "${#missing[@]} required file(s) missing" "${missing[@]}"
    return 1
  fi
  report_pass "$name" "${#REQUIRED_FILES[@]} required files present"
}

# --- 2. foundation version ---------------------------------------------------
# FOUNDATION_VERSION identifies the App-Factory release a repository was built
# from. It is deliberately separate from the ECC upstream version and from the
# AgentShield version; conflating them would make provenance unreadable.
check_foundation_version() {
  local name="foundation_version"
  selected "$name" || return 0
  local file="FOUNDATION_VERSION"
  if [ ! -f "$file" ]; then
    fail_lines "$name" "$file missing"
    return 1
  fi
  local lines value
  lines="$(wc -l < "$file" | tr -d '[:space:]')"
  value="$(head -n 1 "$file" | tr -d '[:space:]')"
  local problems=()
  if [ "$lines" -gt 1 ]; then
    problems+=("$file must contain exactly one line, found $lines")
  fi
  # Semantic version: MAJOR.MINOR.PATCH with optional pre-release/build.
  if ! printf '%s' "$value" |
    grep -qE '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$'; then
    problems+=("not a semantic version: ${value:-<empty>}")
  fi
  local ecc_version
  ecc_version="$(version_value UPSTREAM_VERSION)"
  # Conceptual separation is proved by the two values living in distinct
  # files/fields with distinct meanings, NOT by requiring them to differ
  # numerically. They may legitimately coincide one day; an inequality rule
  # would then force an artificial version bump for no engineering reason.
  # What must hold is that both are present and independently declared.
  if [ -z "$ecc_version" ]; then
    problems+=("UPSTREAM_VERSION is absent from .ecc/VERSION; the ECC version must be declared separately")
  fi
  if grep -qE '^[[:space:]]*(UPSTREAM|AGENTSHIELD)' FOUNDATION_VERSION 2>/dev/null; then
    problems+=("$file must contain only the foundation version, not ECC or scanner provenance")
  fi
  if [ "${#problems[@]}" -gt 0 ]; then
    fail_lines "$name" "${#problems[@]} problem(s) with $file" "${problems[@]}"
    return 1
  fi
  report_pass "$name" "App-Factory foundation v${value} (ECC upstream v${ecc_version:-unknown})"
}

# --- 3. links ----------------------------------------------------------------
# Every relative Markdown link in a tracked .md file must resolve on disk.
extract_md_links() {
  awk '
    /^[[:space:]]*(```|~~~)/ { fence = !fence; next }
    !fence { print }
  ' "$1" |
    grep -oE '\]\([^)[:space:]]+\)' |
    sed -E 's/^\]\(//; s/\)$//'
}

check_links() {
  local name="links"
  selected "$name" || return 0
  local file dir link target broken=() checked=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    dir="$(dirname -- "$file")"
    while IFS= read -r link; do
      [ -n "$link" ] || continue
      case "$link" in
        http://*|https://*|mailto:*|'#'*|'<'*) continue ;;
      esac
      target="${link%%#*}"
      [ -n "$target" ] || continue
      checked=$((checked + 1))
      if [ ! -e "$dir/$target" ]; then
        broken+=("$file -> $link")
      fi
    done < <(extract_md_links "$file")
  done < <(md_files)
  if [ "${#broken[@]}" -gt 0 ]; then
    fail_lines "$name" "${#broken[@]} unresolved link(s)" "${broken[@]}"
    return 1
  fi
  report_pass "$name" "$checked relative link(s) resolve"
}

# --- 4. shell syntax ---------------------------------------------------------
check_shell_syntax() {
  local name="shell_syntax"
  selected "$name" || return 0
  local file bad=() count=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    count=$((count + 1))
    if ! bash -n "$file" 2>/dev/null; then
      bad+=("$file")
    fi
  done < <(shell_files)
  if [ "$count" -eq 0 ]; then
    fail_lines "$name" "no shell scripts tracked"
    return 1
  fi
  if [ "${#bad[@]}" -gt 0 ]; then
    fail_lines "$name" "${#bad[@]} script(s) failed bash -n" "${bad[@]}"
    return 1
  fi
  report_pass "$name" "$count script(s) parse cleanly"
}

# --- 5. shell lint -----------------------------------------------------------
check_shell_lint() {
  local name="shell_lint"
  selected "$name" || return 0
  if ! command -v shellcheck >/dev/null 2>&1; then
    report_skip "$name" "shellcheck not installed (CI runs it)"
    return 0
  fi
  local file bad=() count=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    count=$((count + 1))
    if ! shellcheck --severity=style "$file" >/dev/null 2>&1; then
      bad+=("$file")
    fi
  done < <(shell_files)
  if [ "${#bad[@]}" -gt 0 ]; then
    fail_lines "$name" "shellcheck findings in ${#bad[@]} script(s)" "${bad[@]}"
    return 1
  fi
  report_pass "$name" "$count script(s) clean under shellcheck"
}

# --- 6. executable bits ------------------------------------------------------
check_executable() {
  local name="executable"
  selected "$name" || return 0
  local file bad=() mode
  for file in "${REQUIRED_EXECUTABLES[@]}"; do
    if [ ! -f "$file" ]; then
      bad+=("$file (missing)")
      continue
    fi
    if [ ! -x "$file" ]; then
      bad+=("$file (not executable on disk)")
      continue
    fi
    mode="$(git ls-files -s -- "$file" | awk '{print $1}' | head -n 1)"
    if [ -z "$mode" ]; then
      # Not committed yet: the on-disk bit is all that exists. `git add`
      # preserves it, so this is a note rather than a failure.
      continue
    fi
    if [ "$mode" != "100755" ]; then
      bad+=("$file (git mode $mode, expected 100755)")
    fi
  done
  if [ "${#bad[@]}" -gt 0 ]; then
    fail_lines "$name" "${#bad[@]} script(s) not properly executable" "${bad[@]}"
    return 1
  fi
  report_pass "$name" "${#REQUIRED_EXECUTABLES[@]} script(s) executable on disk and in the index"
}

# --- 7. provenance -----------------------------------------------------------
check_provenance() {
  local name="provenance"
  selected "$name" || return 0
  if [ ! -f .ecc/VERSION ]; then
    fail_lines "$name" ".ecc/VERSION missing"
    return 1
  fi
  local required_keys=(
    ADAPTER_NAME ADAPTER_VERSION UPSTREAM_REPO UPSTREAM_LICENSE
    UPSTREAM_VERSION UPSTREAM_TAG UPSTREAM_COMMIT UPSTREAM_REVIEWED_AT
    AGENTSHIELD_NPM_PACKAGE AGENTSHIELD_NPM_VERSION
    FACTORY_SOURCE_REPO FACTORY_SOURCE_COMMIT
  )
  local key value bad=()
  for key in "${required_keys[@]}"; do
    value="$(version_value "$key")"
    if [ -z "$value" ]; then
      bad+=("$key is empty or absent")
    fi
  done
  local upstream_repo
  upstream_repo="$(version_value UPSTREAM_REPO)"
  case "$upstream_repo" in
    https://github.com/*) : ;;
    *) bad+=("UPSTREAM_REPO is not an https GitHub URL: ${upstream_repo:-<empty>}") ;;
  esac
  local commit
  commit="$(version_value UPSTREAM_COMMIT)"
  if ! printf '%s' "$commit" | grep -qE '^[0-9a-f]{40}$'; then
    bad+=("UPSTREAM_COMMIT is not a 40-char sha: ${commit:-<empty>}")
  fi
  # Factory provenance: where this reusable template itself was derived from.
  local factory_commit
  factory_commit="$(version_value FACTORY_SOURCE_COMMIT)"
  if ! printf '%s' "$factory_commit" | grep -qE '^[0-9a-f]{40}$'; then
    bad+=("FACTORY_SOURCE_COMMIT is not a 40-char sha: ${factory_commit:-<empty>}")
  fi
  if [ ! -f .ecc/UPSTREAM.md ]; then
    bad+=(".ecc/UPSTREAM.md missing")
  else
    grep -qi 'MIT' .ecc/UPSTREAM.md || bad+=(".ecc/UPSTREAM.md does not state the MIT licence")
    grep -qF '.ecc/LICENSE-ECC' .ecc/UPSTREAM.md ||
      bad+=(".ecc/UPSTREAM.md does not reference the committed notice .ecc/LICENSE-ECC")
  fi

  # MIT requires the copyright AND permission notice to travel with adapted
  # material, so the notice is committed here and its integrity is checked
  # rather than left to an external link.
  if [ ! -f .ecc/LICENSE-ECC ]; then
    bad+=(".ecc/LICENSE-ECC missing (upstream MIT notice must be committed)")
  else
    local expected_copy
    expected_copy="$(version_value UPSTREAM_COPYRIGHT)"
    grep -qF "$expected_copy" .ecc/LICENSE-ECC ||
      bad+=(".ecc/LICENSE-ECC is missing the upstream copyright notice")
    grep -qF 'Permission is hereby granted, free of charge' .ecc/LICENSE-ECC ||
      bad+=(".ecc/LICENSE-ECC is missing the MIT permission notice")
    grep -qF 'THE SOFTWARE IS PROVIDED "AS IS"' .ecc/LICENSE-ECC ||
      bad+=(".ecc/LICENSE-ECC is missing the MIT warranty disclaimer")
    local expected_sha actual_sha
    expected_sha="$(version_value UPSTREAM_LICENSE_SHA256)"
    if [ -n "$expected_sha" ] && command -v sha256sum >/dev/null 2>&1; then
      actual_sha="$(sha256sum .ecc/LICENSE-ECC | cut -d' ' -f1)"
      [ "$actual_sha" = "$expected_sha" ] ||
        bad+=(".ecc/LICENSE-ECC sha256 is $actual_sha, expected $expected_sha")
    fi
  fi
  # No claim of native ECC runtime compatibility may creep in.
  local native
  native="$(version_value ADAPTER_NATIVE_ECC_RUNTIME)"
  [ "$native" = "false" ] ||
    bad+=("ADAPTER_NATIVE_ECC_RUNTIME must be false (this is an adaptation, not native ECC)")
  if [ "${#bad[@]}" -gt 0 ]; then
    fail_lines "$name" "${#bad[@]} provenance problem(s)" "${bad[@]}"
    return 1
  fi
  report_pass "$name" "ECC $(version_value UPSTREAM_VERSION) @ ${commit:0:7} recorded with licence"
}

# --- 8. attribution ----------------------------------------------------------
# Every adapted rule/skill/role must carry an ECC attribution header (MIT terms).
check_attribution() {
  local name="attribution"
  selected "$name" || return 0
  local upstream_version
  upstream_version="$(version_value UPSTREAM_VERSION)"
  if [ -z "$upstream_version" ]; then
    fail_lines "$name" "cannot determine UPSTREAM_VERSION from .ecc/VERSION"
    return 1
  fi
  local needle="Adapted from ECC v${upstream_version}"
  local file bad=() count=0
  while IFS= read -r file; do
    case "$file" in
      .ecc/skills/INDEX.md) continue ;;
    esac
    count=$((count + 1))
    grep -qF "$needle" "$file" || bad+=("$file (missing: ${needle})")
  done < <(ecc_files .ecc/rules .ecc/skills .ecc/roles)
  if [ "$count" -eq 0 ]; then
    fail_lines "$name" "no adapted files found under .ecc/rules, .ecc/skills, .ecc/roles"
    return 1
  fi
  if [ "${#bad[@]}" -gt 0 ]; then
    fail_lines "$name" "${#bad[@]} file(s) missing attribution" "${bad[@]}"
    return 1
  fi
  report_pass "$name" "$count adapted file(s) attributed to ECC v${upstream_version}"
}

# --- 9. skill index ----------------------------------------------------------
# Bidirectional: index rows resolve to files, and every workflow is indexed.
check_skill_index() {
  local name="skill_index"
  selected "$name" || return 0
  local index=".ecc/skills/INDEX.md"
  if [ ! -f "$index" ]; then
    fail_lines "$name" "$index missing"
    return 1
  fi
  local problems=()
  local referenced
  mapfile -t referenced < <(grep -oE '\.ecc/(skills|roles)/[A-Za-z0-9._-]+\.md' "$index" | sort -u)
  if [ "${#referenced[@]}" -eq 0 ]; then
    fail_lines "$name" "$index references no workflow paths"
    return 1
  fi
  local path
  for path in "${referenced[@]}"; do
    [ -f "$path" ] || problems+=("index references missing file: $path")
  done
  local file
  while IFS= read -r file; do
    case "$file" in
      .ecc/skills/INDEX.md) continue ;;
    esac
    if ! grep -qF "$file" "$index"; then
      problems+=("workflow not referenced by index: $file")
    fi
  done < <(ecc_files .ecc/skills .ecc/roles)
  if [ "${#problems[@]}" -gt 0 ]; then
    fail_lines "$name" "${#problems[@]} index inconsistency(ies)" "${problems[@]}"
    return 1
  fi
  local size
  size="$(wc -c < "$index" | tr -d '[:space:]')"
  report_pass "$name" "${#referenced[@]} indexed path(s) resolve bidirectionally (${size} bytes)"
}

# --- 10. bootstrap -----------------------------------------------------------
# Every path BOOTSTRAP.md points at must exist, and it must route to every
# workflow in the index. Startup context must also stay small.
check_bootstrap() {
  local name="bootstrap"
  selected "$name" || return 0
  local boot=".ecc/BOOTSTRAP.md"
  if [ ! -f "$boot" ]; then
    fail_lines "$name" "$boot missing"
    return 1
  fi
  local problems=() checked=0
  local always_read=(
    .ecc/BOOTSTRAP.md
    .ecc/rules/engineering.md
    .ecc/skills/INDEX.md
    docs/MEMORY.md
    config/project.env
    scripts/verify.sh
  )
  local f
  for f in "${always_read[@]}"; do
    checked=$((checked + 1))
    [ -e "$f" ] || problems+=("always-read file missing: $f")
    grep -qF "$f" "$boot" || problems+=("bootstrap does not mention always-read file: $f")
  done
  local mention
  while IFS= read -r mention; do
    [ -n "$mention" ] || continue
    mention="${mention%.}"
    checked=$((checked + 1))
    if [ ! -e "$mention" ]; then
      problems+=("bootstrap references missing path: $mention")
    fi
  done < <(grep -oE '(\.ecc|docs|scripts|config|\.github)/[A-Za-z0-9._/-]+' "$boot" | sort -u)
  while IFS= read -r mention; do
    [ -n "$mention" ] || continue
    checked=$((checked + 1))
    [ -f "$mention" ] || problems+=("bootstrap references missing root file: $mention")
  done < <(
    # Root-level UPPERCASE.md mentions only: a preceding path separator means
    # the mention belongs to the path scan above, not to this one.
    grep -oE '(^|[^A-Za-z0-9._/-])[A-Z][A-Za-z0-9_-]*\.md' "$boot" |
      sed -E 's/^[^A-Za-z0-9]//' | sort -u
  )
  local file base
  while IFS= read -r file; do
    case "$file" in
      .ecc/skills/INDEX.md) continue ;;
    esac
    base="$(basename -- "$file")"
    grep -qF "$base" "$boot" || problems+=("bootstrap does not route to workflow: $base")
  done < <(ecc_files .ecc/skills)
  # Startup context must stay small: the whole point of on-demand loading.
  local lines
  lines="$(wc -l < "$boot" | tr -d '[:space:]')"
  if [ "$lines" -gt 220 ]; then
    problems+=("bootstrap is $lines lines; startup context must stay small (<= 220)")
  fi
  if [ "${#problems[@]}" -gt 0 ]; then
    fail_lines "$name" "${#problems[@]} bootstrap problem(s)" "${problems[@]}"
    return 1
  fi
  report_pass "$name" "$checked path reference(s) resolve; bootstrap is $lines lines"
}

# --- 11. CI wiring -----------------------------------------------------------
# CI must invoke the same committed gate, keep least privilege, and keep the
# exact job names that config/main-ruleset.json requires as status contexts.
check_ci_wiring() {
  local name="ci_wiring"
  selected "$name" || return 0
  local wf=".github/workflows/verify.yml"
  if [ ! -f "$wf" ]; then
    fail_lines "$name" "$wf missing"
    return 1
  fi
  local problems=()
  grep -qE '^[[:space:]]*pull_request:' "$wf" || problems+=("no pull_request trigger")
  grep -qE '^[[:space:]]*push:' "$wf" || problems+=("no push trigger")
  grep -qE '^[[:space:]]*workflow_dispatch:' "$wf" || problems+=("no workflow_dispatch trigger")
  # Match the actual invocation, not a mention. A workflow that merely names
  # the script in an unrelated step has still decoupled itself from the gate.
  grep -qE '(^|[[:space:]])(bash|sh)[[:space:]]+scripts/verify\.sh' "$wf" ||
    problems+=("does not invoke scripts/verify.sh")
  grep -qE '(^|[[:space:]])(bash|sh)[[:space:]]+scripts/selftest\.sh' "$wf" ||
    problems+=("does not invoke scripts/selftest.sh")
  # Least privilege: the token must be read-only. Any write scope anywhere in
  # the workflow is a finding, not just a missing 'contents: read'.
  grep -qE '^[[:space:]]*contents:[[:space:]]*read[[:space:]]*$' "$wf" ||
    problems+=("no least-privilege 'contents: read'")
  local write_scopes
  write_scopes="$(grep -nE '^[[:space:]]*[a-z-]+:[[:space:]]*write[[:space:]]*$' "$wf" || true)"
  if [ -n "$write_scopes" ]; then
    problems+=("workflow grants a write permission scope; the gate needs none")
  fi
  grep -qE 'runs-on:' "$wf" || problems+=("no runner declared")
  # Third-party actions must be pinned to a full commit sha, not a tag.
  local uses
  while IFS= read -r uses; do
    [ -n "$uses" ] || continue
    printf '%s' "$uses" | grep -qE '@[0-9a-f]{40}$' ||
      problems+=("action not pinned to a 40-char commit sha: $uses")
  done < <(grep -oE 'uses:[[:space:]]*[A-Za-z0-9._/-]+@[A-Za-z0-9._-]+' "$wf" |
    sed -E 's/^uses:[[:space:]]*//' | sort -u)
  # The job names and the ruleset's required contexts must agree, or the
  # branch silently stops requiring the checks it claims to require.
  local ruleset="config/main-ruleset.json"
  local ctx
  for ctx in "${REQUIRED_CI_CONTEXTS[@]}"; do
    grep -qE "^[[:space:]]*name:[[:space:]]*${ctx}[[:space:]]*$" "$wf" ||
      problems+=("workflow has no job named exactly: ${ctx}")
    if [ -f "$ruleset" ]; then
      grep -qF "\"${ctx}\"" "$ruleset" ||
        problems+=("$ruleset does not require the status context: ${ctx}")
    fi
  done
  if [ "${#problems[@]}" -gt 0 ]; then
    fail_lines "$name" "${#problems[@]} workflow problem(s)" "${problems[@]}"
    return 1
  fi
  report_pass "$name" "CI runs the committed gate as '${REQUIRED_CI_CONTEXTS[0]}' and '${REQUIRED_CI_CONTEXTS[1]}'"
}

# --- 12. secrets -------------------------------------------------------------
# Credential-shaped values must never be committed.
#
# Two properties are load-bearing here and both are covered by
# scripts/selftest.sh:
#
#   1. REDACTION. A finding is reported as "path:line [category]" only. The
#      matched text and the source line are never printed, so a real
#      credential that is accidentally committed cannot be echoed into CI logs
#      by the very check meant to catch it. Matched material stays in memory.
#   2. NO EXEMPTIONS. There is no allowlist of any kind - not "line contains a
#      word like example/todo", and not "value looks like a placeholder". Every
#      match is a finding. A repeated-character value - an all-x or all-zero
#      PASSWORD assignment - is still caught, because a structurally simple
#      value can be a real password. Documentation examples should therefore
#      simply not be credential-shaped: leave the value empty, or use angle
#      brackets, neither of which matches the patterns below.
#
# Patterns are assembled from string fragments so this script does not match
# itself.
check_secrets() {
  local name="secrets"
  selected "$name" || return 0

  # "category|regex" pairs. The category is the only thing reported.
  local -a rules
  rules=(
    'github-classic-token|gh''p_[A-Za-z0-9]{36,}'
    'github-fine-grained-pat|github_''pat_[A-Za-z0-9_]{22,}'
    'github-oauth-token|gho_[A-Za-z0-9]{36,}'
    'github-app-token|ghs_[A-Za-z0-9]{36,}'
    'aws-access-key-id|AK''IA[0-9A-Z]{16}'
    'slack-token|xo''x[baprs]-[A-Za-z0-9-]{10,}'
    'gitlab-pat|gl''pat-[A-Za-z0-9_-]{20,}'
    'google-api-key|AI''za[0-9A-Za-z_-]{35}'
    'openai-style-key|sk''-[A-Za-z0-9_-]{20,}'
    'private-key-block|-----BEGIN ''[A-Z ]*PRIVATE KEY-----'
    'generic-credential-assignment|(API_''KEY|SECRET|TOKEN|PASSWORD|PASSWD|PRIVATE_KEY)[A-Z_]*[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9/+_-]{16,}'
  )

  local -a findings=()
  local rule category regex hits hit loc
  for rule in "${rules[@]}"; do
    category="${rule%%|*}"
    regex="${rule#*|}"
    # -o keeps the surrounding line out of the output, so nothing but the
    # location is ever available to print.
    hits="$(grep -rnoIE --exclude-dir=.git -- "$regex" . 2>/dev/null | sed 's|^\./||')"
    [ -n "$hits" ] || continue
    while IFS= read -r hit; do
      [ -n "$hit" ] || continue
      # hit is "path:line:matched-text". Keep only "path:line"; the matched
      # text is discarded here and never stored, printed, or logged.
      loc="$(printf '%s' "$hit" | sed -E 's/^([^:]+):([0-9]+):.*$/\1:\2/')"
      findings+=("${loc} [${category}]")
    done <<< "$hits"
  done

  local file_count
  file_count="$(find . -type f -not -path './.git/*' | wc -l | tr -d '[:space:]')"
  if [ "${#findings[@]}" -gt 0 ]; then
    fail_lines "$name" "${#findings[@]} credential-shaped value(s) found (values redacted)" \
      "${findings[@]}" \
      "Matched material is intentionally not printed. Open the file at the" \
      "location above to inspect it, and rotate anything already exposed."
    return 1
  fi
  report_pass "$name" "$file_count file(s) scanned, no credential-shaped values"
}

# --- 13. dotenv files --------------------------------------------------------
# .gitignore cannot stop `git add -f`, so the presence of a dotenv file is
# enforced here rather than left to documentation. config/project.env is NOT a
# dotenv file: it is committed lifecycle state, parsed line-by-line and never
# sourced, and it is separately validated by check_lifecycle.
check_env_files() {
  local name="env_files"
  selected "$name" || return 0
  local -a allowed=(.env.example)
  local -a found=()
  local f base ok a
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    base="$(basename -- "$f")"
    ok=0
    for a in "${allowed[@]}"; do
      [ "$base" = "$a" ] && ok=1 && break
    done
    [ "$ok" -eq 1 ] || found+=("$f")
  done < <(
    find . -maxdepth 3 -type f \( -name '.env' -o -name '.env.*' \) -not -path './.git/*' |
      sed 's|^\./||' | LC_ALL=C sort
  )
  if [ "${#found[@]}" -gt 0 ]; then
    fail_lines "$name" "${#found[@]} dotenv file(s) present" "${found[@]}" \
      "Only .env.example may be committed. Secrets belong in the environment."
    return 1
  fi
  report_pass "$name" "no dotenv files committed (only .env.example allowed)"
}

# --- 14. lifecycle -----------------------------------------------------------
# The project lifecycle configuration must be well-formed AND internally
# consistent. In particular, standing the no-stack guard down is only valid as
# a deliberate, documented transition: implementation phase plus an ADR that
# actually exists. This is what stops ALLOW_APP_STACK=1 from being smuggled in
# as a one-character edit, and it is why the guard is no longer a constant
# inside this script.
check_lifecycle() {
  local name="lifecycle"
  selected "$name" || return 0
  if [ ! -f "$PROJECT_CONFIG" ]; then
    fail_lines "$name" "$PROJECT_CONFIG missing (project lifecycle state is required)"
    return 1
  fi
  local problems=()

  # Shape: every non-comment, non-blank line must be KEY=VALUE with an
  # uppercase key. The file is never sourced, so this is about readability and
  # unambiguous parsing, not about execution safety.
  local lineno=0 line
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    case "$line" in
      ''|'#'*) continue ;;
    esac
    printf '%s' "$line" | grep -qE '^[A-Z][A-Z0-9_]*=' ||
      problems+=("$PROJECT_CONFIG:$lineno is not a KEY=VALUE assignment")
  done < "$PROJECT_CONFIG"

  # Required keys must be present, even when empty.
  local key count required_keys=(PROJECT_NAME PROJECT_SLUG PROJECT_PHASE ALLOW_APP_STACK STACK_DECISION_ADR)
  for key in "${required_keys[@]}"; do
    count="$(config_key_count "$key")"
    if [ "$count" -eq 0 ]; then
      problems+=("$PROJECT_CONFIG has no ${key} key")
    elif [ "$count" -gt 1 ]; then
      # Ambiguous state is unsafe state: the parser takes the first
      # assignment, a human reading the file usually takes the last.
      problems+=("$PROJECT_CONFIG assigns ${key} ${count} times; committed lifecycle state must be unambiguous")
    fi
  done

  local phase allow adr slug
  phase="$(config_value PROJECT_PHASE)"
  allow="$(config_value ALLOW_APP_STACK)"
  adr="$(config_value STACK_DECISION_ADR)"
  slug="$(config_value PROJECT_SLUG)"

  case "$phase" in
    factory|discovery|architecture|implementation) : ;;
    *) problems+=("PROJECT_PHASE must be factory|discovery|architecture|implementation, got: ${phase:-<empty>}") ;;
  esac

  case "$allow" in
    0|1) : ;;
    *) problems+=("ALLOW_APP_STACK must be 0 or 1, got: ${allow:-<empty>}") ;;
  esac

  if [ -n "$slug" ] && ! printf '%s' "$slug" | grep -qE '^[a-z0-9][a-z0-9-]*$'; then
    problems+=("PROJECT_SLUG must be lowercase kebab-case, got: $slug")
  fi

  # The transition rule, evaluated by the shared validator so that this check
  # and check_no_app_stack can never disagree about what is legitimate.
  if [ "$allow" = "1" ]; then
    validate_stack_transition problems || :
  else
    # Guard is up. An ADR reference is allowed (the decision may be recorded
    # before the transition PR), but it must still resolve if present.
    if [ -n "$adr" ] && [ ! -f "$adr" ]; then
      problems+=("STACK_DECISION_ADR points at a file that does not exist: $adr")
    fi
  fi

  # Lifecycle state must not carry credentials.
  if grep -qE '^[[:space:]]*[A-Z_]*(SECRET|TOKEN|PASSWORD|API_KEY|PRIVATE_KEY)[A-Z_]*[[:space:]]*=[[:space:]]*[^[:space:]]' "$PROJECT_CONFIG"; then
    problems+=("$PROJECT_CONFIG contains a credential-shaped key with a value; lifecycle state must never hold secrets")
  fi

  if [ "${#problems[@]}" -gt 0 ]; then
    fail_lines "$name" "${#problems[@]} lifecycle configuration problem(s)" "${problems[@]}"
    return 1
  fi
  report_pass "$name" "phase=${phase}, allow_app_stack=${allow}${adr:+, adr=${adr}}"
}

# --- 15. no application stack ------------------------------------------------
# Lifecycle-aware. In factory/discovery/architecture phases the foundation
# rejects application-stack artifacts. After an explicit, ADR-backed transition
# recorded in config/project.env, this FOUNDATION guard stands down — which is
# not the same as the project being tested: stack-specific lint/test/build
# gates are added separately at that point.
check_no_app_stack() {
  local name="no_app_stack"
  selected "$name" || return 0
  local allow phase adr
  allow="$(config_value ALLOW_APP_STACK)"
  phase="$(config_value PROJECT_PHASE)"
  adr="$(config_value STACK_DECISION_ADR)"
  # Fail closed: an unreadable or absent value keeps the guard up.
  [ -n "$allow" ] || allow="0"
  if [ "$allow" = "1" ]; then
    # This check must NOT assume check_lifecycle ran. `verify.sh
    # --only=no_app_stack` reaches this line with nothing else validated, so
    # the transition is re-validated here through the shared helper. A guard
    # that stands down on an unverified claim is not a guard.
    local -a transition_problems=()
    if ! validate_stack_transition transition_problems; then
      fail_lines "$name" "ALLOW_APP_STACK=1 but the transition is not valid; guard stays up" \
        "${transition_problems[@]}" \
        "The foundation no-stack guard only stands down for an explicit," \
        "ADR-backed transition. Fix ${PROJECT_CONFIG} or the referenced ADR."
      return 1
    fi
    report_skip "$name" "guard stood down: phase=${phase}, ADR=${adr:-<none>} (stack-specific checks apply instead)"
    return 0
  fi
  local -a forbidden_files
  forbidden_files=(
    package.json package-lock.json yarn.lock pnpm-lock.yaml bun.lockb
    requirements.txt pyproject.toml Pipfile poetry.lock setup.py
    go.mod Cargo.toml Gemfile composer.json pom.xml build.gradle
    Dockerfile docker-compose.yml tsconfig.json Makefile
  )
  local -a forbidden_dirs
  forbidden_dirs=(src app lib client server frontend backend api)
  local found=() entry
  for entry in "${forbidden_files[@]}"; do
    [ -e "$entry" ] && found+=("$entry")
  done
  for entry in "${forbidden_dirs[@]}"; do
    if [ -d "$entry" ]; then
      found+=("${entry}/")
    fi
  done
  if [ "${#found[@]}" -gt 0 ]; then
    fail_lines "$name" "${#found[@]} application-stack artifact(s) present" \
      "${found[@]}" \
      "This repository is in the '${phase:-unknown}' phase, where a stack is not yet allowed." \
      "A stack choice requires an approved issue and an ADR in docs/decisions/." \
      "If that has happened, transition the repository in ${PROJECT_CONFIG}:" \
      "  PROJECT_PHASE=implementation, ALLOW_APP_STACK=1, STACK_DECISION_ADR=docs/decisions/NNNN-....md" \
      "Do not edit this script to make the guard pass."
    return 1
  fi
  report_pass "$name" "no framework, database, build, or UI artifacts committed (phase=${phase:-unknown})"
}

# --- 16. ruleset -------------------------------------------------------------
# config/main-ruleset.json must parse, be portable (no instance-specific ids),
# and encode the branch-protection intent the workflow depends on.
check_ruleset() {
  local name="ruleset"
  selected "$name" || return 0
  local file="config/main-ruleset.json"
  if [ ! -f "$file" ]; then
    fail_lines "$name" "$file missing"
    return 1
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    report_skip "$name" "python3 unavailable for structural validation (CI provides it)"
    return 0
  fi

  # Structural validation, not text matching. This file's sole purpose is to be
  # POSTed to the GitHub rulesets API, so the check must assert the shape the
  # API will actually read: a policy string sitting in a decoy location, or a
  # required context nested under the wrong rule, must not satisfy it.
  local out rc
  out="$(
    REQUIRED_CONTEXT_1="${REQUIRED_CI_CONTEXTS[0]}" \
    REQUIRED_CONTEXT_2="${REQUIRED_CI_CONTEXTS[1]}" \
    RULESET_FILE="$file" \
    python3 - <<'PYEOF' 2>&1
import json
import os
import sys

path = os.environ["RULESET_FILE"]
wanted_contexts = [os.environ["REQUIRED_CONTEXT_1"], os.environ["REQUIRED_CONTEXT_2"]]
problems = []

try:
    with open(path, encoding="utf-8") as fh:
        doc = json.load(fh)
except (OSError, ValueError) as exc:
    print("%s is not valid JSON: %s" % (path, exc))
    sys.exit(1)

if not isinstance(doc, dict):
    print("%s must be a JSON object (the API request body)" % path)
    sys.exit(1)

# 1. Portability. An export carries server-assigned state; a reusable template
#    must not. Unknown keys are rejected too: the payload is applied verbatim,
#    so anything the API does not document is either noise or a mistake.
allowed_top_level = {
    "name", "target", "enforcement", "conditions", "bypass_actors", "rules",
}
export_only = {
    "id", "node_id", "repository_id", "created_at", "updated_at",
    "source", "source_type", "_links", "current_user_can_bypass", "links",
}
for key in sorted(doc):
    if key in export_only:
        problems.append("instance-specific/export key present: %r" % key)
    elif key not in allowed_top_level:
        problems.append("unexpected top-level key: %r" % key)

for key in sorted(allowed_top_level - set(doc)):
    problems.append("missing required top-level key: %r" % key)

# 2. Target and scope.
if doc.get("target") != "branch":
    problems.append("target must be 'branch', got %r" % (doc.get("target"),))
if doc.get("enforcement") != "active":
    problems.append("enforcement must be 'active', got %r" % (doc.get("enforcement"),))

conditions = doc.get("conditions")
if not isinstance(conditions, dict):
    problems.append("conditions must be an object")
else:
    ref_name = conditions.get("ref_name")
    if not isinstance(ref_name, dict):
        problems.append("conditions.ref_name must be an object")
    else:
        include = ref_name.get("include")
        if include != ["~DEFAULT_BRANCH"]:
            problems.append(
                "conditions.ref_name.include must be exactly ['~DEFAULT_BRANCH'], got %r" % (include,)
            )
        if ref_name.get("exclude") not in ([], None):
            problems.append(
                "conditions.ref_name.exclude must be empty, got %r" % (ref_name.get("exclude"),)
            )

# 3. No bypass actors. An empty list is required; absent or populated is not.
bypass = doc.get("bypass_actors")
if not isinstance(bypass, list):
    problems.append("bypass_actors must be a list")
elif bypass:
    problems.append("bypass_actors must be empty, got %d entry(ies)" % len(bypass))

# 4. Rules, indexed by type so position cannot matter.
rules = doc.get("rules")
by_type = {}
if not isinstance(rules, list):
    problems.append("rules must be a list")
else:
    for index, rule in enumerate(rules):
        if not isinstance(rule, dict):
            problems.append("rules[%d] must be an object" % index)
            continue
        rule_type = rule.get("type")
        if not isinstance(rule_type, str):
            problems.append("rules[%d] has no string 'type'" % index)
            continue
        if rule_type in by_type:
            problems.append("duplicate rule type: %r" % rule_type)
        by_type[rule_type] = rule

for required_type in ("deletion", "non_fast_forward", "pull_request", "required_status_checks"):
    if required_type not in by_type:
        problems.append("missing required rule type: %r" % required_type)

# 5. Pull-request policy, read from the rule's own parameters object.
pr_rule = by_type.get("pull_request")
if isinstance(pr_rule, dict):
    params = pr_rule.get("parameters")
    if not isinstance(params, dict):
        problems.append("pull_request rule has no parameters object")
    else:
        if params.get("required_approving_review_count") != 0:
            problems.append(
                "pull_request.required_approving_review_count must be 0 (solo-owner workflow), got %r"
                % (params.get("required_approving_review_count"),)
            )
        if params.get("required_review_thread_resolution") is not True:
            problems.append(
                "pull_request.required_review_thread_resolution must be true, got %r"
                % (params.get("required_review_thread_resolution"),)
            )

# 6. Status checks: strict policy plus the exact two portable contexts.
sc_rule = by_type.get("required_status_checks")
if isinstance(sc_rule, dict):
    params = sc_rule.get("parameters")
    if not isinstance(params, dict):
        problems.append("required_status_checks rule has no parameters object")
    else:
        if params.get("strict_required_status_checks_policy") is not True:
            problems.append(
                "strict_required_status_checks_policy must be true (branch must be up to date), got %r"
                % (params.get("strict_required_status_checks_policy"),)
            )
        checks = params.get("required_status_checks")
        if not isinstance(checks, list):
            problems.append("required_status_checks.required_status_checks must be a list")
        else:
            found = []
            for index, check in enumerate(checks):
                if not isinstance(check, dict):
                    problems.append("required_status_checks[%d] must be an object" % index)
                    continue
                context = check.get("context")
                if not isinstance(context, str):
                    problems.append("required_status_checks[%d] has no string 'context'" % index)
                    continue
                found.append(context)
            for wanted in wanted_contexts:
                if wanted not in found:
                    problems.append(
                        "required status context missing from the status-check rule: %r" % wanted
                    )

for problem in problems:
    print(problem)
sys.exit(1 if problems else 0)
PYEOF
  )"
  rc=$?

  local problems=()
  if [ "$rc" -ne 0 ]; then
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      problems+=("$line")
    done <<< "$out"
  fi

  # A maintainer must be told how to apply it; nothing here applies it.
  grep -qF 'config/main-ruleset.json' docs/FACTORY.md 2>/dev/null ||
    problems+=("docs/FACTORY.md does not document how to apply $file")

  if [ "${#problems[@]}" -gt 0 ]; then
    fail_lines "$name" "${#problems[@]} ruleset problem(s)" "${problems[@]}"
    return 1
  fi
  report_pass "$name" "portable payload: PR, thread resolution, strict checks, no bypass, no export fields"
}

# --- 17. AgentShield ---------------------------------------------------------
check_agentshield() {
  local name="agentshield"
  selected "$name" || return 0
  if [ "$AGENTSHIELD_MODE" = "off" ]; then
    report_skip "$name" "disabled (VERIFY_AGENTSHIELD=off)"
    return 0
  fi
  local pkg ver
  pkg="$(version_value AGENTSHIELD_NPM_PACKAGE)"
  ver="$(version_value AGENTSHIELD_NPM_VERSION)"
  if [ -z "$pkg" ] || [ -z "$ver" ]; then
    if [ "$AGENTSHIELD_MODE" = "require" ]; then
      fail_lines "$name" "scanner not pinned in .ecc/VERSION"
      return 1
    fi
    report_skip "$name" "scanner not pinned in .ecc/VERSION"
    return 0
  fi
  if ! command -v npx >/dev/null 2>&1; then
    if [ "$AGENTSHIELD_MODE" = "require" ]; then
      fail_lines "$name" "npx unavailable in required mode"
      return 1
    fi
    report_skip "$name" "npx unavailable"
    return 0
  fi
  local out rc
  # Static mode only. The deep modes (--injection, --sandbox, --taint, --deep)
  # execute or actively probe configuration and are never run automatically.
  out="$(timeout 600 npx --yes "${pkg}@${ver}" scan --format json 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ] || [ -z "$out" ]; then
    if [ "$AGENTSHIELD_MODE" = "require" ]; then
      fail_lines "$name" "scan failed or produced no output (exit $rc)"
      return 1
    fi
    report_skip "$name" "scanner unreachable (exit $rc); not counted as passed"
    return 0
  fi
  local critical high files
  if command -v jq >/dev/null 2>&1; then
    critical="$(printf '%s' "$out" | jq -r '.summary.critical // 0')"
    high="$(printf '%s' "$out" | jq -r '.summary.high // 0')"
    files="$(printf '%s' "$out" | jq -r '.summary.filesScanned // 0')"
  else
    critical="$(printf '%s' "$out" | sed -n 's/.*"critical":[[:space:]]*\([0-9]*\).*/\1/p' | head -n 1)"
    high="$(printf '%s' "$out" | sed -n 's/.*"high":[[:space:]]*\([0-9]*\).*/\1/p' | head -n 1)"
    files="$(printf '%s' "$out" | sed -n 's/.*"filesScanned":[[:space:]]*\([0-9]*\).*/\1/p' | head -n 1)"
  fi
  critical="${critical:-0}"; high="${high:-0}"; files="${files:-0}"
  if [ "$critical" -gt 0 ] || [ "$high" -gt 0 ]; then
    fail_lines "$name" "${pkg}@${ver}: $critical critical, $high high finding(s)"
    return 1
  fi
  # A scan that examined nothing proves nothing. AgentShield targets Claude
  # Code configuration surfaces (.claude/, hooks, MCP config); this Arena
  # adapter has none, so the honest result is SKIP, not PASS. Reporting it as
  # a pass would advertise security coverage that does not exist.
  if [ "$files" -eq 0 ]; then
    report_skip "$name" "${pkg}@${ver} ran but scanned 0 file(s): no Claude config surface here (advisory only)"
    return 0
  fi
  report_pass "$name" "${pkg}@${ver} static scan clean ($files file(s) scanned)"
}

# --- 18. workflow YAML -------------------------------------------------------
check_workflows_yaml() {
  local name="workflows_yaml"
  selected "$name" || return 0
  local parser=""
  if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
    parser="python3"
  fi
  if [ -z "$parser" ]; then
    report_skip "$name" "no YAML parser available (CI installs PyYAML)"
    return 0
  fi
  local file bad=() count=0
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    count=$((count + 1))
    if ! python3 -c 'import sys, yaml; yaml.safe_load(open(sys.argv[1]))' "$file" >/dev/null 2>&1; then
      bad+=("$file")
    fi
  done < <(workflow_files)
  if [ "$count" -eq 0 ]; then
    fail_lines "$name" "no workflow files tracked"
    return 1
  fi
  if [ "${#bad[@]}" -gt 0 ]; then
    fail_lines "$name" "${#bad[@]} workflow file(s) failed to parse" "${bad[@]}"
    return 1
  fi
  report_pass "$name" "$count workflow file(s) parse as YAML"
}

# --- Registration ------------------------------------------------------------
register foundation
register foundation_version
register links
register shell_syntax
register shell_lint
register executable
register provenance
register attribution
register skill_index
register bootstrap
register ci_wiring
register secrets
register env_files
register lifecycle
register no_app_stack
register ruleset
register agentshield
register workflows_yaml

usage() {
  sed -n '2,22p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# --- Argument parsing --------------------------------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --list) LIST_ONLY=1 ;;
    --only=*) SELECTED+=("${1#--only=}") ;;
    --only) shift; SELECTED+=("${1:-}") ;;
    --skip-agentshield) AGENTSHIELD_MODE="off" ;;
    --require-agentshield) AGENTSHIELD_MODE="require" ;;
    --quiet|-q) QUIET=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'verify.sh: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

if [ "$LIST_ONLY" -eq 1 ]; then
  printf '%s\n' "${CHECK_ORDER[@]}"
  exit 0
fi

for want in "${SELECTED[@]}"; do
  known=0
  for name in "${CHECK_ORDER[@]}"; do
    [ "$name" = "$want" ] && known=1 && break
  done
  if [ "$known" -eq 0 ]; then
    printf 'verify.sh: unknown check: %s\n' "$want" >&2
    printf 'available: %s\n' "${CHECK_ORDER[*]}" >&2
    exit 2
  fi
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  printf 'verify.sh: must run inside a git repository\n' >&2
  exit 2
fi

# --- Run ---------------------------------------------------------------------
say "App-Factory foundation verification gate"
say "  repo:       $REPO_ROOT"
say "  foundation: $(head -n 1 FOUNDATION_VERSION 2>/dev/null || echo unknown)"
say "  branch:     $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
say "  commit:     $(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
say "  phase:      $(config_value PROJECT_PHASE), allow_app_stack=$(config_value ALLOW_APP_STACK)"
say "  mode:       agentshield=${AGENTSHIELD_MODE}"
say "------------------------------------------------------------"

for check in "${CHECK_ORDER[@]}"; do
  "check_${check}"
done

say "------------------------------------------------------------"
if [ "$FAIL_COUNT" -gt 0 ]; then
  printf '%sRESULT: FAIL%s — %d passed, %d failed, %d skipped\n' \
    "$c_fail" "$c_reset" "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
  printf '\nFailures:\n'
  for msg in "${FAILURE_MESSAGES[@]}"; do
    printf '  - %s\n' "$msg"
  done
  exit 1
fi

# A run in which nothing was even attempted is a failure: it would otherwise
# report success having verified nothing. A SKIP is a reported outcome, not an
# absence of one, so it counts here (a selected check that legitimately stands
# down still produced a verdict).
if [ "$((PASS_COUNT + SKIP_COUNT))" -eq 0 ]; then
  printf '%sRESULT: NO CHECKS RAN%s — nothing was verified\n' "$c_fail" "$c_reset"
  exit 1
fi

printf '%sRESULT: PASS%s — %d passed, %d failed, %d skipped\n' \
  "$c_pass" "$c_reset" "$PASS_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"
exit 0
