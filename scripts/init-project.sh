#!/usr/bin/env bash
# One-time project identity setup for a repository generated from App-Factory.
#
# What it does, and nothing more: writes PROJECT_NAME, PROJECT_SLUG, and moves
# PROJECT_PHASE from "factory" to "discovery" in config/project.env.
#
# What it deliberately does NOT do:
#   - never commits, pushes, tags, or creates a branch;
#   - never changes any GitHub setting (visibility, rulesets, secrets, apps);
#   - never rewrites ECC provenance or licence files (.ecc/VERSION,
#     .ecc/UPSTREAM.md, .ecc/LICENSE-ECC) or FOUNDATION_VERSION;
#   - never mass-replaces text across the repository;
#   - never invents a product requirement, stack, or roadmap;
#   - never sets ALLOW_APP_STACK — that transition needs an ADR and review.
#
# It is safe to run twice: an already-initialized repository is reported and
# left untouched unless --force is given. --force rewrites identity only and
# preserves the lifecycle phase and stack state, so it can never leave
# config/project.env in a state that scripts/verify.sh would reject.
#
# Usage:
#   scripts/init-project.sh --name "My Project"   initialize
#   scripts/init-project.sh                       infer the name from git origin
#   scripts/init-project.sh --slug my-project     override the derived slug
#   scripts/init-project.sh --dry-run             show the change, write nothing
#   scripts/init-project.sh --force               reset identity on an initialized repo
#   scripts/init-project.sh --help                usage
#
# Exit status: 0 on success or a no-op, 1 on a refusal, 2 on a usage error.

set -uo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd -- "$REPO_ROOT" || exit 2

CONFIG="config/project.env"

NAME=""
SLUG=""
DRY_RUN=0
FORCE=0

usage() { sed -n '2,28p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --name) shift; NAME="${1:-}" ;;
    --name=*) NAME="${1#--name=}" ;;
    --slug) shift; SLUG="${1:-}" ;;
    --slug=*) SLUG="${1#--slug=}" ;;
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'init-project.sh: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

die() { printf 'init-project.sh: %s\n' "$*" >&2; exit 1; }

config_value() {
  sed -n "s/^[[:space:]]*${1}[[:space:]]*=[[:space:]]*//p" "$CONFIG" 2>/dev/null |
    head -n 1 | sed 's/[[:space:]]*$//'
}

[ -f "$CONFIG" ] || die "$CONFIG not found. Run this from a repository generated from App-Factory."

# --- Refuse to run on an already-initialized repository ----------------------
CURRENT_NAME="$(config_value PROJECT_NAME)"
CURRENT_PHASE="$(config_value PROJECT_PHASE)"

if [ "$FORCE" -eq 0 ] && { [ -n "$CURRENT_NAME" ] || [ "$CURRENT_PHASE" != "factory" ]; }; then
  printf 'Already initialized — nothing to do.\n'
  printf '  PROJECT_NAME:  %s\n' "${CURRENT_NAME:-<empty>}"
  printf '  PROJECT_PHASE: %s\n' "${CURRENT_PHASE:-<empty>}"
  printf '\nThis script is non-destructive and will not overwrite an initialized\n'
  printf 'project. Edit %s by hand, or re-run with --force.\n' "$CONFIG"
  exit 0
fi

# --- Decide the target phase -------------------------------------------------
# --force re-initializes IDENTITY only. It must never regress the lifecycle,
# because rewriting an implementation-phase project back to discovery while
# leaving ALLOW_APP_STACK=1 in place produces a state the gate rejects - a
# "safe" script would have corrupted the repository it was asked to set up.
# Moving a project backwards through the lifecycle is a reviewed decision, not
# a side effect of re-running an init helper.
TARGET_PHASE="discovery"
if [ "$CURRENT_PHASE" != "factory" ] && [ -n "$CURRENT_PHASE" ]; then
  TARGET_PHASE="$CURRENT_PHASE"
fi

# --- Determine the project name ---------------------------------------------
# Inferring from git is a convenience for naming only. It never invents a
# product definition, a stack, or a requirement.
if [ -z "$NAME" ]; then
  origin="$(git config --get remote.origin.url 2>/dev/null || true)"
  if [ -n "$origin" ]; then
    NAME="$(basename -- "${origin%.git}")"
  fi
fi

if [ -z "$NAME" ]; then
  die "could not determine a project name. Pass --name \"My Project\"."
fi

# Reject anything that is not a plain, printable, single-line name. This keeps
# shell metacharacters, newlines, and control characters out of a committed
# config file that other scripts parse.
if ! printf '%s' "$NAME" | grep -qE '^[A-Za-z0-9][A-Za-z0-9 ._-]{0,63}$'; then
  die "invalid --name: use 1-64 characters of letters, digits, space, dot, underscore or hyphen."
fi

if [ -z "$SLUG" ]; then
  SLUG="$(printf '%s' "$NAME" |
    tr '[:upper:]' '[:lower:]' |
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
fi

if ! printf '%s' "$SLUG" | grep -qE '^[a-z0-9][a-z0-9-]{0,63}$'; then
  die "invalid slug '${SLUG}': use lowercase kebab-case. Pass --slug explicitly."
fi

# --- Show the planned change -------------------------------------------------
printf 'Project initialization\n'
printf '  repository:    %s\n' "$REPO_ROOT"
printf '  foundation:    %s\n' "$(head -n 1 FOUNDATION_VERSION 2>/dev/null || echo unknown)"
printf '  PROJECT_NAME:  %s -> %s\n' "${CURRENT_NAME:-<empty>}" "$NAME"
printf '  PROJECT_SLUG:  %s -> %s\n' "$(config_value PROJECT_SLUG)" "$SLUG"
if [ "$TARGET_PHASE" = "${CURRENT_PHASE:-}" ]; then
  printf '  PROJECT_PHASE: %s (preserved — --force sets identity only)\n' "$TARGET_PHASE"
else
  printf '  PROJECT_PHASE: %s -> %s\n' "${CURRENT_PHASE:-<empty>}" "$TARGET_PHASE"
fi
printf '  ALLOW_APP_STACK: unchanged (%s) — a stack needs an issue, an ADR and review\n' \
  "$(config_value ALLOW_APP_STACK)"

if [ "$DRY_RUN" -eq 1 ]; then
  printf '\n--dry-run: nothing was written.\n'
  exit 0
fi

# --- Write, atomically, preserving comments and key order --------------------
TMP="$(mktemp "${TMPDIR:-/tmp}/app-factory-init.XXXXXX")" || die "could not create a temp file"
# Invoked only via the EXIT trap, which shellcheck does not treat as a call
# site. Both codes are listed because the version decides which one is
# reported: 0.11 flags SC2329 at the definition, 0.9 flags SC2317 on the body.
# See the same note in scripts/verify.sh.
# shellcheck disable=SC2317,SC2329
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

# Values are injected via awk -v, not interpolated into a script body, so a
# name containing awk or shell metacharacters cannot alter the program.
awk -v name="$NAME" -v slug="$SLUG" -v phase="$TARGET_PHASE" '
  /^[[:space:]]*PROJECT_NAME[[:space:]]*=/  { print "PROJECT_NAME=" name; next }
  /^[[:space:]]*PROJECT_SLUG[[:space:]]*=/  { print "PROJECT_SLUG=" slug; next }
  /^[[:space:]]*PROJECT_PHASE[[:space:]]*=/ { print "PROJECT_PHASE=" phase; next }
  { print }
' "$CONFIG" > "$TMP" || die "failed to rewrite $CONFIG"

[ -s "$TMP" ] || die "refusing to write an empty $CONFIG"

# Sanity-check the result before replacing the original.
for key in PROJECT_NAME PROJECT_SLUG PROJECT_PHASE ALLOW_APP_STACK STACK_DECISION_ADR; do
  grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$TMP" ||
    die "refusing to write: ${key} would be lost from $CONFIG"
done

cat "$TMP" > "$CONFIG" || die "failed to update $CONFIG"

printf '\nUpdated %s. Nothing else was modified.\n' "$CONFIG"
printf '\nNext steps (all of them are yours to perform):\n'
printf '  1. Review the diff:   git diff -- %s\n' "$CONFIG"
printf '  2. Run the gate:      bash scripts/verify.sh\n'
printf '  3. Run negative tests: bash scripts/selftest.sh\n'
printf '  4. Commit it yourself. This script does not commit or push.\n'
printf '  5. Complete the GitHub-admin checklist in docs/FACTORY.md — repository\n'
printf '     visibility, the branch ruleset, app installation and Actions\n'
printf '     permissions are NOT inherited from a template and no script here\n'
printf '     changes them.\n'
printf '  6. Open a product-discovery issue; see docs/PRODUCT.md.\n'

exit 0
