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
set -euo pipefail

SPIKE_DIR="${1:?usage: swift-typecheck.sh SPIKE_DIR LABEL}"
LABEL="${2:?usage: swift-typecheck.sh SPIKE_DIR LABEL}"
readonly SPIKE_DIR LABEL
readonly LOG="${SPIKE_DIR}/typecheck-${LABEL}.log"

cd -- "$SPIKE_DIR"

swift_file="$(find generated/swift -name '*.swift' | head -n 1)"
modulemap="$(find generated/apple -name 'module.modulemap' | head -n 1)"
if [ -z "$swift_file" ] || [ -z "$modulemap" ]; then
  echo "missing generated Swift ('${swift_file}') or modulemap ('${modulemap}')" >&2
  exit 1
fi
readonly swift_file modulemap
headers_dir="$(dirname -- "$modulemap")"
readonly headers_dir

sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"

echo "SWIFT_TYPECHECK_LABEL=${LABEL}"
echo "SWIFT_TYPECHECK_FILE=${swift_file}"
echo "SWIFT_TYPECHECK_HEADERS_DIR=${headers_dir}"
echo "SWIFT_TYPECHECK_MODULEMAP=$(cat -- "$modulemap")"

set +e
xcrun --sdk iphonesimulator swiftc \
  -typecheck \
  -swift-version 6 \
  -target arm64-apple-ios16.0-simulator \
  -sdk "$sdk_path" \
  -I "$headers_dir" \
  "$swift_file" >"$LOG" 2>&1
status=$?
set -e

echo "SWIFT_TYPECHECK_${LABEL}_EXIT=${status}"
tail -n 40 "$LOG" || true
exit "$status"
