#!/usr/bin/env bash
# Type-check the *generated* Swift under the project's Swift 6 language mode,
# with no app, no scheme and no Xcode project in the way.
#
# This is the cheap, precise RED/GREEN probe for the Swift 6 async regression: it
# compiles the generator's own output, so it isolates the generator fix from
# anything the host test file might get wrong.
#
# Usage: swift-typecheck.sh SPIKE_DIR LABEL
# Exit status is swiftc's. Log: SPIKE_DIR/typecheck-LABEL.log
#
# `-parse-as-library` matters: without it swiftc treats the first generated file as
# top-level code, where Swift 6 isolates top-level declarations to the main actor -
# and then the two `private let boltffi...PollCallback` globals are reported as
# "main actor-isolated ... can not be referenced from a nonisolated context", which
# the app's own Swift 6 build does not report (apps/ios: SWIFT_VERSION = 6.0, and
# the app compiles this same file). Those two diagnostics are an artifact of the
# probe's invocation, not a property of the generated code, and they also confounded
# the differential experiment: the parameters-only variant failed on them instead of
# on the Sendable diagnostic it exists to test.
set -euo pipefail

SPIKE_DIR="$(cd -- "${1:?usage: swift-typecheck.sh SPIKE_DIR LABEL}" && pwd)"
LABEL="${2:?usage: swift-typecheck.sh SPIKE_DIR LABEL}"
readonly SPIKE_DIR LABEL
# Absolute on purpose: the compile is redirected into LOG *after* cd'ing into
# SPIKE_DIR, so a relative LOG made the redirect itself fail - which silently
# skipped swiftc and reported "RED failed for the wrong reason" (run 35099091021).
readonly LOG="${SPIKE_DIR}/typecheck-${LABEL}.log"

cd -- "$SPIKE_DIR"

# Where the Swift API lands depends on the SPM layout the project configures:
#   ffi-only / bundled -> <targets.apple.spm.output, default targets.apple.output>/Sources/BoltFFI
#   split              -> <targets.apple.swift.output>/BoltFFI
# apple-proof.sh searches the same two places, so a layout change can never make
# this probe silently type-check nothing.
swift_files=()
while IFS= read -r file; do
  [ -n "$file" ] && swift_files+=("$file")
done < <(find generated/apple/Sources generated/swift -name '*.swift' 2>/dev/null | sort -u)
modulemap="$(find generated/apple -name 'module.modulemap' 2>/dev/null | head -n 1)"

echo "SWIFT_TYPECHECK_LABEL=${LABEL}"
if [ "${#swift_files[@]}" -eq 0 ] || [ -z "$modulemap" ]; then
  # Fail loudly and *attributably*: a missing artifact is a harness result, not
  # a compiler result, and the next reader needs to see which one it was.
  echo "SWIFT_TYPECHECK_MISSING swift_files=${#swift_files[@]} modulemap=${modulemap:-none}"
  echo "---- generated tree (bounded) ----"
  find generated -maxdepth 4 -print 2>/dev/null | head -n 60
  echo "no generated Swift under generated/apple/Sources or generated/swift, or no module.modulemap under generated/apple" >&2
  exit 1
fi
for file in "${swift_files[@]}"; do
  echo "SWIFT_TYPECHECK_FILE=${file}"
done
headers_dir="$(dirname -- "$modulemap")"

sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"

echo "SWIFT_TYPECHECK_MODULEMAP=${modulemap}"
echo "SWIFT_TYPECHECK_HEADERS_DIR=${headers_dir}"
echo "SWIFT_TYPECHECK_MODULEMAP_CONTENT=$(cat -- "$modulemap")"

set +e
xcrun --sdk iphonesimulator swiftc \
  -typecheck \
  -swift-version 6 \
  -parse-as-library \
  -target arm64-apple-ios16.0-simulator \
  -sdk "$sdk_path" \
  -I "$headers_dir" \
  "${swift_files[@]}" >"$LOG" 2>&1
status=$?
set -e

echo "SWIFT_TYPECHECK_${LABEL}_EXIT=${status}"
tail -n 40 "$LOG" || true
exit "$status"
