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
#   --exclude PREFIX          skip every patch whose file name starts with
#                             PREFIX (repeatable). Used to build the RED runtime
#                             for a single patch: same generator, one fix removed.
#
# Patches are cumulative and their file names fix the order (0001 .. 0004).
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
EXCLUDES=()
while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT_DIR="$2"; shift 2 ;;
    --verify-only) VERIFY_ONLY=1; shift ;;
    --skip-patches) SKIP_PATCHES=1; shift ;;
    --apply-only) APPLY_ONLY=1; shift ;;
    --exclude) EXCLUDES+=("$2"); shift 2 ;;
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
patches=()
for candidate in "${PATCH_DIR}"/*.patch; do
  name="$(basename -- "$candidate")"
  skip=0
  for exclude in ${EXCLUDES[@]+"${EXCLUDES[@]}"}; do
    case "$name" in
      "$exclude"*) skip=1 ;;
    esac
  done
  if [ "$skip" -eq 1 ]; then
    echo "BOLTFFI_EXCLUDED_PATCH=${name}"
    continue
  fi
  patches+=("$candidate")
done
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

# --- 3. fail closed, cumulatively ---
# Patches build on each other: 0004 edits the same file as 0001, so checking
# every patch against the *pristine* tree would reject a correct patch set. Each
# patch is therefore checked against the tree as the earlier ones left it, and a
# failure rolls the checkout back so a failed run never leaves a half-patched
# generator behind for the next step to build from.
for patch in "${patches[@]}"; do
  if ! git apply --check -- "$patch"; then
    echo "patch $(basename -- "$patch") does not apply on top of the patches before it" >&2
    git checkout --quiet -- .
    echo "BOLTFFI_APPLIED=none (checkout rolled back to ${BASE_SHA})" >&2
    exit 1
  fi
  if ! git apply -- "$patch"; then
    echo "patch $(basename -- "$patch") failed to apply after passing its check" >&2
    git checkout --quiet -- .
    echo "BOLTFFI_APPLIED=none (checkout rolled back to ${BASE_SHA})" >&2
    exit 1
  fi
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
