#!/usr/bin/env bash
# Apple native proof for the patched BoltFFI candidate.
#
# Modes (both integrate the *current* generated/ tree into a throwaway copy of
# the real Greenfield5 Xcode project, so every mode compiles with the project's
# own Swift 6 / iOS 16 settings and nothing is weakened):
#
#   test      (default) real Rust: contract, ownership, streams and the lifetime
#             probe together - the acceptance run. Requires the Rust contract
#             markers (BOLT_PROOF, BOLT_BACKLOG) in addition to the lifetime ones.
#   lifetime  the lifetime probe alone, against the model of the Rust future
#             contract (no native library behaviour needed). This is the RED/GREEN
#             pair for patch 0004: the same test file, run against a generator
#             with and without the fix.
#
# The Swift 6 compilation RED (unpatched generator) and the parameters-only
# differential probe live in swift-typecheck.sh, which type-checks the generated
# Swift directly - cheaper and more precise than a full xcodebuild, and it keeps
# the failure attributable to the generator instead of to the app.
#
# Every xcodebuild invocation is bounded (PR #17 lesson), and every log stays on
# disk so a wedge is diagnosable instead of silent.
set -euo pipefail

MODE="${1:-test}"
case "$MODE" in
  test | lifetime) ;;
  *)
    echo "usage: apple-proof.sh [test|lifetime]" >&2
    exit 2
    ;;
esac
readonly MODE

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SPIKE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$SPIKE_DIR/../.." && pwd)"
readonly SCRIPT_DIR SPIKE_DIR REPO_ROOT
readonly RUN_BOUNDED="${SCRIPT_DIR}/run-with-timeout.py"

cd -- "$SPIKE_DIR"

app="${SPIKE_DIR}/generated/ios-app"
rm -rf -- "$app"
cp -R "${REPO_ROOT}/apps/ios" "$app"
echo "APPLE_APP_COPY=${app}"
# xcodebuild resolves -project relative to its working directory, so every
# bounded invocation below runs inside this copy.
readonly APP_DIR="${app}"

framework="$(find generated/apple -name '*.xcframework' -maxdepth 4 | head -n 1)"
if [ -z "$framework" ]; then
  echo "no generated xcframework under generated/apple" >&2
  exit 1
fi
bridge="${app}/Greenfield5/Bridge/Generated"
rm -rf -- "$bridge"
mkdir -p -- "$bridge"
cp -R "$framework" "${bridge}/Greenfield5Core.xcframework"
echo "APPLE_FRAMEWORK=${framework}"

# Array-free accumulation: macOS /bin/bash is 3.2, where `mapfile` does not exist.
generated_sources=()
while IFS= read -r source; do
  [ -n "$source" ] && generated_sources+=("$source")
done < <(find generated/apple/Sources generated/swift -name '*.swift' 2>/dev/null)
if [ "${#generated_sources[@]}" -eq 0 ]; then
  echo "no generated Swift API found under generated/apple or generated/swift" >&2
  exit 1
fi
for source in "${generated_sources[@]}"; do
  cp "$source" "${bridge}/$(basename -- "$source")"
done
echo "APPLE_GENERATED_SWIFT_FILES=${#generated_sources[@]}"

# The control's own bridge tests exercise the UniFFI bridge and cannot compile
# against the candidate; they are not weakened, they are replaced in this copy
# only. The production tree keeps them.
rm -f -- "${app}/Greenfield5Tests/BridgeTests.swift"
{
  echo "@testable import Greenfield5"
  cat host/LifetimeProbe.swift
} >"${app}/Greenfield5Tests/BoltLifetimeProbe.swift"
if [ "$MODE" = "test" ]; then
  {
    echo "@testable import Greenfield5"
    cat host/Contract.swift
  } >"${app}/Greenfield5Tests/BoltContract.swift"
fi

simulator_udid="$(python3 - <<'PY'
import json, subprocess
devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
for runtime in sorted(devices["devices"], reverse=True):
    for device in devices["devices"][runtime]:
        if "iPhone" in device["name"]:
            print(device["udid"])
            raise SystemExit(0)
raise SystemExit("no available iPhone simulator")
PY
)"
echo "APPLE_SIMULATOR_UDID=${simulator_udid}"

base=(xcodebuild -project Greenfield5.xcodeproj -scheme Greenfield5
  -destination "platform=iOS Simulator,id=${simulator_udid}"
  -configuration Debug CODE_SIGNING_ALLOWED=NO)

echo "---- generated public API surface ----"
grep -hE '^(public|@_|extension)' "${generated_sources[@]}" | sort -u | head -n 200

set +e
( cd -- "$APP_DIR" && python3 "$RUN_BOUNDED" 420 "${SPIKE_DIR}/build.log" "${base[@]}" build )
build_status=$?
set -e
echo "APPLE_TEST_BUILD_EXIT=${build_status}"
tail -n 20 build.log || true
if [ "$build_status" -ne 0 ]; then
  # The whole point of a bounded, self-announcing proof: a compile failure must
  # print its diagnostics here instead of leaving a bare exit code behind.
  echo "---- build diagnostics ----"
  grep -E "error:" build.log | head -n 60 || true
  exit "$build_status"
fi

set +e
( cd -- "$APP_DIR" && python3 "$RUN_BOUNDED" 600 "${SPIKE_DIR}/test.log" "${base[@]}" test \
  -parallel-testing-enabled NO -maximum-test-execution-time-allowance 90 -test-timeouts-enabled YES )
test_status=$?
set -e
echo "APPLE_TEST_EXIT=${test_status}"
tail -n 60 test.log
grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*|Executed [0-9]+ test|Test run with [0-9]+ test|Test Case .* (passed|failed)' test.log | tail -n 30 || true
if [ "$test_status" -ne 0 ]; then
  echo "---- test diagnostics ----"
  grep -E "error:|XCTAssert|recorded an issue|failed" test.log | tail -n 60 || true
  exit "$test_status"
fi

grep -q '\*\* TEST SUCCEEDED \*\*' test.log
grep -q 'BOLT_LIFETIME' test.log
if [ "$MODE" = "test" ]; then
  # The real-Rust acceptance markers. In lifetime mode the probe only needs the
  # generated runtime, so these are asserted by the acceptance run instead.
  grep -q 'BOLT_PROOF version=0.1.0' test.log
  grep -q 'BOLT_BACKLOG' test.log
  grep -E "BOLT_PROOF|BOLT_ERR|BOLT_BACKLOG|BOLT_BOUNDED|BOLT_CANCEL|BOLT_LIFETIME" test.log | tail -n 20 || true
fi
# XCTest reports "Executed N tests"; swift-testing reports "Test run with N
# tests passed". Require one of the two counts, so "TEST SUCCEEDED" alone can
# never be mistaken for "tests actually ran".
if ! grep -qE 'Executed [0-9]+ tests?' test.log &&
  ! grep -qE 'Test run with [0-9]+ tests? passed' test.log; then
  echo "xcodebuild reported success but no executed-test count was found; refusing to call that a pass" >&2
  exit 1
fi

echo "APPLE_NATIVE_PROOF=complete"
