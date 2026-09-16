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

# --- 2. assembly happens per phase, below: the debug variant, the minified
#        release variant and the instrumentation APK are all produced and run,
#        so both the packaging requirement and real execution are covered.
# --- 3. one emulator image, chosen explicitly and recorded ---
if ! "$SDKMANAGER" --list_installed 2>/dev/null | grep -Fq "$SYSTEM_IMAGE"; then
  yes | "$SDKMANAGER" --licenses >/dev/null 2>&1 || true
  "$SDKMANAGER" "emulator" "platform-tools" "$SYSTEM_IMAGE"
fi
"$SDKMANAGER" --list_installed | grep -E 'system-images|emulator|platform-tools' || true

# --- 4. acceleration, prepared and then *proved*, before blaming the image ---
# GitHub's hosted Ubuntu runners expose /dev/kvm to the runner user only through
# a udev rule; without it the emulator fails with "x86_64 emulation currently
# requires hardware acceleration" and "This user doesn't have permissions to use
# KVM (/dev/kvm)". The rule below is the established CI practice and is scoped to
# this ephemeral runner (it is never part of the product tree, and it grants no
# privilege beyond letting the ephemeral runner user open the node it already
# owns a device for).
echo "ANDROID_KVM_PRESENT=$([ -e /dev/kvm ] && echo yes || echo no)"
ls -l /dev/kvm 2>&1 || true
if [ -e /dev/kvm ] && [ ! -w /dev/kvm ]; then
  echo "ANDROID_KVM_NOT_WRITABLE=yes (preparing udev rule)"
  echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
    | sudo tee /etc/udev/rules.d/99-kvm4all.rules
  sudo udevadm control --reload-rules
  sudo udevadm trigger --name-match=kvm
fi
echo "ANDROID_KVM_READABLE=$([ -r /dev/kvm ] && echo yes || echo no)"
echo "ANDROID_KVM_WRITABLE=$([ -w /dev/kvm ] && echo yes || echo no)"
ls -l /dev/kvm 2>&1 || true
grep -c -E '(vmx|svm)' /proc/cpuinfo || true
echo "ANDROID_NPROC=$(nproc)"
free -m || true

# Fail closed before an AVD is created or an emulator is started: an unusable
# accelerator is an infrastructure failure, never a candidate result.
if [ ! -e /dev/kvm ]; then
  echo "ANDROID_ACCEL_UNUSABLE=no /dev/kvm node on this runner" >&2
  exit 1
fi
if [ ! -r /dev/kvm ] || [ ! -w /dev/kvm ]; then
  echo "ANDROID_ACCEL_UNUSABLE=/dev/kvm exists but $USER cannot read/write it" >&2
  exit 1
fi
accel_report="$("$EMULATOR" -accel-check 2>&1 || true)"
printf '%s\n' "$accel_report"
if ! printf '%s\n' "$accel_report" | grep -qiE 'is installed and usable|accel: 0|KVM.*usable'; then
  echo "ANDROID_ACCEL_UNUSABLE=emulator -accel-check did not report a usable accelerator" >&2
  exit 1
fi
echo "ANDROID_ACCEL=usable"

# --- 5. reuse a booted device when there is one, otherwise boot with a finite
#        ceiling and a diagnosable failure ---
emulator_pid=""
booted=0
"$ADB" start-server >/dev/null 2>&1 || true
if [ "$("$ADB" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" = "1" ]; then
  echo "ANDROID_EMULATOR_REUSED=$("$ADB" get-serialno 2>/dev/null || true)"
  booted=1
else
  # The emulator only searches ANDROID_AVD_HOME, ANDROID_SDK_HOME/avd and
  # $HOME/.android/avd for <name>.ini. Pin the location for avdmanager so the
  # AVD is created exactly where the emulator looks, then prove it exists -
  # "avdmanager exited 0" is not evidence that an AVD was written.
  export ANDROID_AVD_HOME="${HOME}/.android/avd"
  mkdir -p -- "$ANDROID_AVD_HOME"
  echo "ANDROID_AVD_HOME=${ANDROID_AVD_HOME}"
  echo "ANDROID_HOME=${HOME}"
  echo "ANDROID_USER_HOME=${ANDROID_USER_HOME:-<unset>}"
  echo "ANDROID_SDK_HOME=${ANDROID_SDK_HOME:-<unset>}"
  echo no | "$AVDMANAGER" create avd -n "$AVD_NAME" -k "$SYSTEM_IMAGE" --force
  "$AVDMANAGER" list avd || true
  if [ ! -f "${ANDROID_AVD_HOME}/${AVD_NAME}.ini" ]; then
    echo "avdmanager did not write ${ANDROID_AVD_HOME}/${AVD_NAME}.ini" >&2
    echo "---- searching for the AVD it did write ----" >&2
    find / -name "${AVD_NAME}.ini" -print 2>/dev/null | head -5 >&2 || true
    echo "---- candidate AVD roots ----" >&2
    find "${HOME}/.android" -maxdepth 2 -print 2>/dev/null | head -20 >&2 || true
    find "${ANDROID_HOME}" -maxdepth 3 -name '*.avd' -print 2>/dev/null | head -5 >&2 || true
    exit 1
  fi

  emulator_log="${SPIKE_DIR}/emulator.log"
  emulator_cmd=("$EMULATOR" -avd "$AVD_NAME" -no-window -no-audio -no-boot-anim
    -gpu swiftshader_indirect -no-snapshot -no-metrics -accel auto)
  printf 'EMULATOR_CMD=%s\n' "${emulator_cmd[*]}"
  "${emulator_cmd[@]}" >"$emulator_log" 2>&1 &
  emulator_pid=$!
  # A prefixed run (the RED probe) tears its device down; an unprefixed run
  # leaves the booted device for the probe, so one boot serves both.
  if [ -n "$LOG_PREFIX" ]; then
    trap 'if [ -n "$emulator_pid" ]; then kill "$emulator_pid" 2>/dev/null || true; fi; "$ADB" emu kill 2>/dev/null || true' EXIT
  fi

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
    echo "ANDROID_BOOT_FAILED after ${elapsed}s (ceiling ${BOOT_CEILING_SECONDS}s)" >&2
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
# Two phases. A minified release build is where R8 would strip the generated
# bridge if the keep rules were wrong, so the same instrumentation runs against
# both variants instead of trusting a debug-only run. Each phase assembles its
# own APKs (and clears stale outputs first, so discovery can never pick up the
# other variant's artifact).
install_and_run() {
  local label="$1" class="$2" timeout_seconds="$3" log="${LOG_PREFIX}$4"
  local app_apk="$5" test_apk="$6"
  "$ADB" install -r -t "$app_apk"
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

run_phase() {
  local variant="$1" assemble_task="$2"
  local upper="${variant^^}"
  rm -rf android/build/outputs/apk
  "$REPO_ROOT/apps/android/gradlew" -p android "-PproofTestBuildType=${variant}" \
    "$assemble_task" assembleAndroidTest --no-daemon
  local app_apk test_apk
  app_apk="$(find android/build/outputs/apk -name '*.apk' -not -path '*/androidTest/*' | head -n 1)"
  test_apk="$(find android/build/outputs/apk -name '*.apk' -path '*/androidTest/*' | head -n 1)"
  for apk in "$app_apk" "$test_apk"; do
    if [ -z "$apk" ] || [ ! -s "$apk" ]; then
      echo "expected ${variant} APK missing after ${assemble_task} (app='${app_apk}' test='${test_apk}')" >&2
      find android/build/outputs -name '*.apk' >&2 || true
      exit 1
    fi
  done
  echo "ANDROID_${upper}_APP_APK=$(basename -- "$app_apk") bytes=$(wc -c <"$app_apk" | tr -d ' ') sha256=$(sha256sum -- "$app_apk" | cut -d' ' -f1)"
  echo "ANDROID_${upper}_TEST_APK=$(basename -- "$test_apk") bytes=$(wc -c <"$test_apk" | tr -d ' ') sha256=$(sha256sum -- "$test_apk" | cut -d' ' -f1)"

  install_and_run "${upper}_CONTRACT" "NativeContractTest" 300 "${variant}-contract.log" "$app_apk" "$test_apk"
  grep -q 'BOLT_PROOF version=0.1.0' "${LOG_PREFIX}${variant}-contract.log"
  grep -E 'BOLT_PROOF|BOLT_STREAM' "${LOG_PREFIX}${variant}-contract.log" || true
  grep -E 'BOLT_PROOF|BOLT_STREAM' "${LOG_PREFIX}${upper}_CONTRACT-logcat.txt" || true
  grep -q 'BOLT_STREAM' "${LOG_PREFIX}${variant}-contract.log" "${LOG_PREFIX}${upper}_CONTRACT-logcat.txt"

  install_and_run "${upper}_CLOSE" "ConcurrentCloseTest" 300 "${variant}-close.log" "$app_apk" "$test_apk"
  grep -q 'BOLT_CLOSE' "${LOG_PREFIX}${variant}-close.log" "${LOG_PREFIX}${upper}_CLOSE-logcat.txt"
  grep 'BOLT_CLOSE' "${LOG_PREFIX}${variant}-close.log" "${LOG_PREFIX}${upper}_CLOSE-logcat.txt" || true
}

# Debug first (the primary execution evidence), then the minified release
# variant, where an R8/keep-rule mistake would fail a real run instead of a
# static grep. Both are recorded, so the order is only about log readability.
run_phase debug assembleDebug
run_phase release assembleRelease

echo "ANDROID_NATIVE_PROOF=complete"
