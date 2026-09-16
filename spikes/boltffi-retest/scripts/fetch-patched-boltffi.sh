#!/usr/bin/env bash
# Fetch BoltFFI at an exact immutable commit, verify it, and apply the tracked
# spike patches. Nothing here is a dependency of the product tree: the checkout
# lives under a caller-supplied scratch directory.
#
# Modes
#   --out DIR                 clone at the pinned commit, then apply the patches
#   --out DIR --skip-patches  clone at the pinned commit only (the RED baseline)
#   --verify-only             hash the patches, no checkout
#   --out DIR --apply-only    apply the patches to an existing checkout,
#                             resetting any previous application first
#
# Emits machine-readable provenance lines (BOLTFFI_BASE=, BOLTFFI_PATCH_SHA256=,
# ...) on stdout so a CI step can publish them as evidence.
set -euo pipefail

# boltffi v0.30.1 -- the tag already pinned by the candidate manifest. Patch
# context was generated against this exact tree; a different base fails closed.
readonly BASE_SHA="2e6320a6d92cb591d22b908477f3a47da7ebc9bc"
readonly BASE_TAG="v0.30.1"
readonly REPO_URL="https://github.com/boltffi/boltffi.git"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly PATCH_DIR="${SCRIPT_DIR}/../patches"

# Portable digest: the Apple job runs on macOS, which ships shasum rather than
# sha256sum. Either tool is acceptable as long as the emitted value is SHA-256.
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$1" | cut -d' ' -f1
  else
    openssl dgst -sha256 -- "$1" | sed 's/.*= //'
  fi
}

sha256_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | cut -d' ' -f1
  else
    openssl dgst -sha256 | sed 's/.*= //'
  fi
}

OUT_DIR=""
VERIFY_ONLY=0
SKIP_PATCHES=0
APPLY_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="$2"; shift 2 ;;
    --verify-only) VERIFY_ONLY=1; shift ;;
    --skip-patches) SKIP_PATCHES=1; shift ;;
    --apply-only) APPLY_ONLY=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ "$VERIFY_ONLY" -eq 0 ] && [ -z "$OUT_DIR" ]; then
  echo "--out DIR is required" >&2
  exit 2
fi
if [ "$SKIP_PATCHES" -eq 1 ] && [ "$APPLY_ONLY" -eq 1 ]; then
  echo "--skip-patches and --apply-only are mutually exclusive" >&2
  exit 2
fi

echo "BOLTFFI_BASE_TAG=${BASE_TAG}"
echo "BOLTFFI_BASE_SHA=${BASE_SHA}"

# --- 1. patch provenance: hash every tracked patch before applying anything ---
shopt -s nullglob
patches=("${PATCH_DIR}"/*.patch)
if [ "${#patches[@]}" -eq 0 ]; then
  echo "no patches found under ${PATCH_DIR}" >&2
  exit 1
fi
for patch in "${patches[@]}"; do
  name="$(basename -- "$patch")"
  hash="$(sha256_of "$patch")"
  echo "BOLTFFI_PATCH=${name} BOLTFFI_PATCH_SHA256=${hash}"
done

if [ "$VERIFY_ONLY" -eq 1 ]; then
  echo "BOLTFFI_VERIFY_ONLY=1 (patch hashes computed, no checkout performed)"
  exit 0
fi

# --- 2. exact-commit checkout (no branch, no tag lookup, no reflog drift) ---
mkdir -p -- "$OUT_DIR"
cd -- "$OUT_DIR"
if [ "$APPLY_ONLY" -eq 0 ]; then
  if [ ! -d .git ]; then
    git init --quiet .
    git remote add origin "$REPO_URL"
  fi
  git remote set-url origin "$REPO_URL"
  git fetch --quiet --depth 1 origin "$BASE_SHA"
  git checkout --quiet --detach FETCH_HEAD
else
  if [ ! -d .git ]; then
    echo "--apply-only requires an existing checkout at ${OUT_DIR}" >&2
    exit 1
  fi
  # Idempotent: an earlier unpatched run (or a re-run) must not stack patches.
  git checkout --quiet -- .
fi

actual="$(git rev-parse HEAD)"
echo "BOLTFFI_CHECKOUT_SHA=${actual}"
if [ "$actual" != "$BASE_SHA" ]; then
  echo "checkout SHA mismatch: expected ${BASE_SHA}, got ${actual}" >&2
  exit 1
fi

if [ "$SKIP_PATCHES" -eq 1 ]; then
  echo "BOLTFFI_PATCHED=no (unpatched baseline requested)"
  echo "BOLTFFI_CHANGED_FILES="
  echo "BOLTFFI_DIFFSTAT= 0 files changed"
  exit 0
fi

# --- 3. fail closed before mutating anything ---
for patch in "${patches[@]}"; do
  git apply --check -- "$patch"
done
for patch in "${patches[@]}"; do
  git apply -- "$patch"
  echo "BOLTFFI_APPLIED=$(basename -- "$patch")"
done

# --- 4. the patched tree is the artifact; record it ---
echo "BOLTFFI_PATCHED=yes"
echo "BOLTFFI_CHANGED_FILES=$(git diff --name-only | tr '\n' ',')"
echo "BOLTFFI_DIFFSTAT=$(git diff --shortstat)"
echo "BOLTFFI_PATCHED_TREE_SHA256=$(git diff | sha256_stdin)"

# The generator templates are compiled into the CLI by askama's
# #[template(path = ...)], so building the CLI from this checkout is what puts
# the patches into the generated Swift/Kotlin. Nothing edits generated output.
