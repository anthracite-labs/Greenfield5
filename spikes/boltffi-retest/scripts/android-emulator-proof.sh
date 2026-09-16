#!/usr/bin/env bash
# Android native proof for the patched BoltFFI candidate.
#
# Runs in CI after `boltffi pack android` has populated generated/. Assembles
# debug, minified release and instrumentation APKs, boots one emulator image (or
# reuses one that is already booted, so the same script can also produce a RED
# probe against the unpatched generation), then drives the candidate through
# real JNI into the real Rust library.
#
# PR #18 stopped here: the boot wait exited 124 and nothing explained why. This
# script therefore records the emulator command line, the selected image, the
# acceleration report, adb state, boot properties and the emulator's own
# stdout/stderr, and it never waits unboundedly.
#
# Usage: android-emulator-proof.sh [LOG_PREFIX]
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SPIKE_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd -- "$SPIKE_DIR/../.." && pwd)"

# Optional label prefix so the same script can produce the GREEN evidence and,
# separately, a RED probe against the unpatched generation without either run
# overwriting the other's logs.
LOG_PREFIX="${1:-}"
readonly LOG_PREFIX
readonly SPIKE_DIR REPO_ROOT
readonly API_LEVEL=29
readonly SYSTEM_IMAGE="system-images;android-${API_LEVEL};google_apis;x86_64"
readonly AVD_NAME="boltproof"
readonly BOOT_CEILING_SECONDS=900

ANDROID_HOME="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [ -z "$ANDROID_HOME" ] || [ ! -d "$ANDROID_HOME" ]; then
  echo "ANDROID_HOME/ANDROID_SDK_ROOT is not a directory: '${ANDROID_HOME}'" >&2
  exit 1
fi
readonly ANDROID_HOME
readonly SDKMANAGER="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
readonly AVDMANAGER="${ANDROID_HOME}/cmdline-tools/latest/bin/avdmanager"
readonly ADB="${ANDROID_HOME}/platform-tools/adb"
readonly EMULATOR="${ANDROID_HOME}/emulator/emulator"

cd -- "$SPIKE_DIR"
echo "ANDROID_IMAGE=${SYSTEM_IMAGE}"
echo "ANDROID_API_LEVEL=${API_LEVEL}"
echo "ANDROID_SDK_ROOT=${ANDROID_HOME}"
echo "ANDROID_LOG_PREFIX=${LOG_PREFIX:-<none>}"

# --- 1. the candidate must be a real JNI build, with no JNA anywhere ---
for abi in arm64-v8a x86_64; do
  test -s "generated/jniLibs/${abi}/libgreenfield5_bolt_spike.so"
done
# -I keeps grep from reporting "Binary file ... matches" on built payloads,
# which would be a false positive.
if grep -rqiI "jna" android/build.gradle.kts android/settings.gradle.kts host/ generated/ 2>/dev/null; then
  echo "JNA reference found in the candidate; the point of this spike is that it needs none" >&2
  grep -rniI "jna" android/build.gradle.kts android/settings.gradle.kts host/ 2>/dev/null | head -5 >&2
  exit 1
fi
echo "ANDROID_NO_JNA=confirmed"

# --- 2. assemble debug, minified release and instrumentation ---
"$REPO_ROOT/apps/android/gradlew" -p android \
  assembleDebug assembleRelease assembleDebugAndroidTest --no-daemon

# APK file names follow rootProject.name, so discover them instead of assuming
# a name that a project rename would silently invalidate.
debug_apk="$(find android/build/outputs/apk/debug -name '*.apk' | head -n 1)"
release_apk="$(find android/build/outputs/apk/release -name '*.apk' | head -n 1)"
test_apk="$(find android/build/outputs/apk/androidTest -name '*.apk' | head -n 1)"
for apk in "$debug_apk" "$release_apk" "$test_apk"; do
  if [ -z "$apk" ] || [ ! -s "$apk" ]; then
    echo "expected APK missing after assemble (debug='${debug_apk}' release='${release_apk}' test='${test_apk}')" >&2
    find android/build/outputs -name '*.apk' >&2 || true
    exit 1
  fi
  echo "ANDROID_APK=$(basename -- "$apk") bytes=$(wc -c <"$apk" | tr -d ' ')"
done
readonly debug_apk release_apk test_apk

# --- 3. one emulator image, chosen explicitly and recorded ---
if ! "$SDKMANAGER" --list_installed 2>/dev/null | grep -Fq "$SYSTEM_IMAGE"; then
  yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
  "$SDKMANAGER" "emulator" "platform-tools" "$SYSTEM_IMAGE"
fi
"$SDKMANAGER" --list_installed | grep -E 'system-images|emulator|platform-tools' || true

# --- 4. acceleration and host capability, before blaming the image ---
echo "ANDROID_KVM_PRESENT=$([ -e /dev/kvm ] && echo yes || echo no)"
ls -l /dev/kvm 2>&1 || true
grep -c -E '(vmx|svm)' /proc/cpuinfo || true
echo "ANDROID_NPROC=$(nproc)"
free -m || true
"$EMULATOR" -accel-check 2>&1 || true

# --- 5. reuse a booted device when there is one, otherwise boot with a finite
#        ceiling and a diagnosable failure ---
emulator_pid=""
booted=0
"$ADB" start-server >/dev/null 2>&1 || true
if [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" = "1" ]; then
  echo "ANDROID_EMULATOR_REUSED=$("$ADB" get-serialno 2>/dev/null || true)"
  booted=1
else
  echo no | "$AVDMANAGER" create avd -n "$AVD_NAME" -k "$SYSTEM_IMAGE" --force

  emulator_log="${SPIKE_DIR}/emulator.log"
  emulator_cmd=("$EMULATOR" -avd "$AVD_NAME" -no-window -no-audio -no-boot-anim
    -gpu swiftshader_indirect -no-snapshot -no-metrics -accel auto)
  printf 'EMULATOR_CMD=%s\n' "${emulator_cmd[*]}"
  "${emulator_cmd[@]}" >"$emulator_log" 2>&1 &
  emulator_pid=$!
  trap 'if [ -n "$emulator_pid" ]; then kill "$emulator_pid" 2>/dev/null || true; fi; "$ADB" emu kill 2>/dev/null || true' EXIT

  for elapsed in $(seq 0 10 "$BOOT_CEILING_SECONDS"); do
    if ! kill -0 "$emulator_pid" 2>/dev/null; then
      echo "ANDROID_EMULATOR_EXITED early after ${elapsed}s"
      break
    fi
    state="$("$ADB" get-state 2>/dev/null || true)"
    completed="$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
    if [ "$completed" = "1" ]; then
      echo "ANDROID_BOOT_COMPLETED after ${elapsed}s (adb state=${state})"
      booted=1
      break
    fi
    if [ $((elapsed % 60)) -eq 0 ]; then
      echo "ANDROID_BOOT_WAIT elapsed=${elapsed}s adb_state='${state}' sys.boot_completed='${completed}'"
      "$ADB" devices || true
    fi
    sleep 10
  done

  if [ "$booted" -ne 1 ]; then
    echo "ANDROID_BOOT_FAILED after ${BOOT_CEILING_SECONDS}s ceiling" >&2
    echo "---- adb devices ----" >&2
    "$ADB" devices -l >&2 || true
    echo "---- adb get-state ----" >&2
    "$ADB" get-state >&2 || true
    echo "---- emulator.log (tail 120) ----" >&2
    tail -n 120 "$emulator_log" >&2 || true
    echo "---- boot properties (tail 40) ----" >&2
    "$ADB" shell getprop >&2 | tail -n 40 || true
    echo "---- emulator process state ----" >&2
    ps -o pid,stat,etime,cmd -p "$emulator_pid" >&2 || true
    exit 1
  fi
fi

"$ADB" shell input keyevent 82 || true

# --- 6. real Kotlin -> generated bindings -> JNI -> Rust execution ---
install_and_run() {
  local label="$1" class="$2" timeout_seconds="$3" log="${LOG_PREFIX}$4"
  "$ADB" install -r -t "$debug_apk"
  "$ADB" install -r -t "$test_apk"
  "$ADB" logcat -c
  if ! timeout "$timeout_seconds" "$ADB" shell am instrument -w \
    -e class "dev.greenfield5.boltproof.${class}" \
    dev.greenfield5.boltproof.test/androidx.test.runner.AndroidJUnitRunner >"$log" 2>&1; then
    echo "ANDROID_${label}_INSTRUMENTATION_FAILED (or timed out after ${timeout_seconds}s)" >&2
    cat "$log" >&2
    exit 1
  fi
  cat "$log"
  grep -q 'OK (1 test)' "$log"
  "$ADB" logcat -d >"${LOG_PREFIX}${label}-logcat.txt" 2>&1 || true
  echo "ANDROID_${label}=PASS"
}

install_and_run "CONTRACT" "NativeContractTest" 300 contract.log
grep -q 'BOLT_PROOF version=0.1.0' "${LOG_PREFIX}contract.log"
grep -E 'BOLT_PROOF|BOLT_STREAM' "${LOG_PREFIX}contract.log" || true
grep -E 'BOLT_PROOF|BOLT_STREAM' "${LOG_PREFIX}CONTRACT-logcat.txt" || true
grep -q 'BOLT_STREAM' "${LOG_PREFIX}contract.log" "${LOG_PREFIX}CONTRACT-logcat.txt"

install_and_run "CLOSE" "ConcurrentCloseTest" 300 close.log
grep -q 'BOLT_CLOSE' "${LOG_PREFIX}close.log" "${LOG_PREFIX}CLOSE-logcat.txt"
grep 'BOLT_CLOSE' "${LOG_PREFIX}close.log" "${LOG_PREFIX}CLOSE-logcat.txt" || true

echo "ANDROID_NATIVE_PROOF=complete"
