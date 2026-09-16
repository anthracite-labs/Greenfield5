#!/usr/bin/env bash
# Apple native proof for the patched BoltFFI candidate.
#
# Modes (all integrate the *current* generated/ tree into a throwaway copy of
# the real Greenfield5 Xcode project, so every mode compiles with the project's
# own Swift 6 / iOS 16 settings and nothing is weakened):
#
#   red      bounded build that MUST fail, with the non-Sendable diagnostics
#            that motivate patch 0001 (the RED half of the regression)
#   partial  bounded build of the parameters-only variant; records whether
#            `@Sendable` alone is enough, i.e. whether `T: Sendable` is required.
#            Never fails the job: it exists to answer that question with a
#            compiler, not with an opinion.
#   test     bounded build + native test run + marker/assertion gate (default)
#
# Every xcodebuild invocation is bounded (PR #17 lesson), and every log stays on
# disk so a wedge is diagnosable instead of silent.
set -euo pipefail

MODE="${1:-test}"
case "$MODE" in
  red | partial | test) ;;
  *)
    echo "usage: apple-proof.sh [red|partial|test]" >&2
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
  cat host/Contract.swift
} >"${app}/Greenfield5Tests/BoltContract.swift"

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

if [ "$MODE" = "red" ] || [ "$MODE" = "partial" ]; then
  log="${MODE}-build.log"
  set +e
  ( cd -- "$APP_DIR" && python3 "$RUN_BOUNDED" 420 "${SPIKE_DIR}/${log}" "${base[@]}" build )
  status=$?
  set -e
  echo "APPLE_${MODE}_BUILD_EXIT=${status}"
  tail -n 40 "$log" || true
  python3 - "${SPIKE_DIR}/${log}" "$status" "$MODE" <<'PY'
import re, sys
log, status, mode = sys.argv[1], int(sys.argv[2]), sys.argv[3]
lines = open(log, errors="replace").read().splitlines()
sendable = [ln for ln in lines if re.search(r"sendable", ln, re.I)]
errors = [ln for ln in lines if "error:" in ln]
def notice(title, body):
    body = body.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")[:900]
    print(f"::notice title={title}::{body}")
if mode == "red":
    if status == 0:
        print("::error title=BoltFFI RED not reproduced::the unpatched v0.30.1 generated Swift built cleanly under Swift 6; the premise of patch 0001 must be re-researched.")
        raise SystemExit(1)
    if len(sendable) < 2:
        print("::error title=BoltFFI RED did not fail on Sendable::the unpatched generated Swift failed to build, but not with the non-Sendable diagnostics patch 0001 addresses.")
        print("\n".join(errors[:10]))
        raise SystemExit(1)
    notice("BoltFFI RED (Swift 6)", "unpatched v0.30.1 rejected by the real project:\n" + "\n".join(sendable[:6]))
    raise SystemExit(0)
# partial: evidence only, never fatal.
notice(
    "BoltFFI differential (params only)",
    f"cancel/free @Sendable WITHOUT T: Sendable -> xcodebuild exit {status}; "
    f"{len(sendable)} sendable-related line(s)\n" + "\n".join((sendable or errors)[:6]),
)
raise SystemExit(0)
PY
  exit $?
fi

( cd -- "$APP_DIR" && python3 "$RUN_BOUNDED" 420 "${SPIKE_DIR}/build.log" "${base[@]}" build )
( cd -- "$APP_DIR" && python3 "$RUN_BOUNDED" 600 "${SPIKE_DIR}/test.log" "${base[@]}" test \
  -parallel-testing-enabled NO -maximum-test-execution-time-allowance 90 -test-timeouts-enabled YES )

tail -n 40 build.log
grep -E "error:|warning:.*Sendable" build.log | head -n 40 || true
tail -n 60 test.log
grep -E '\*\* TEST (SUCCEEDED|FAILED) \*\*|Executed [0-9]+ test|Test run with [0-9]+ test|Test Case .* (passed|failed)' test.log | tail -n 30 || true

grep -q '\*\* TEST SUCCEEDED \*\*' test.log
grep -q 'BOLT_PROOF version=0.1.0' test.log
grep -q 'BOLT_BACKLOG' test.log
# XCTest reports "Executed N tests"; swift-testing reports "Test run with N
# tests passed". Require one of the two counts, so "TEST SUCCEEDED" alone can
# never be mistaken for "tests actually ran".
if ! grep -qE 'Executed [0-9]+ tests?' test.log &&
  ! grep -qE 'Test run with [0-9]+ tests? passed' test.log; then
  echo "xcodebuild reported success but no executed-test count was found; refusing to call that a pass" >&2
  exit 1
fi

echo "APPLE_NATIVE_PROOF=complete"
