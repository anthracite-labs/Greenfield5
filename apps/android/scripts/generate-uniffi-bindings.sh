#!/usr/bin/env bash
set -euo pipefail

# Generates Kotlin bindings for Greenfield5 core (UniFFI 0.32.1)
# Called from CI after Rust Android libs built.
# Inputs: core/target/release/libgreenfield5_core.so (host) or .dylib on macOS
# Outputs: apps/android/app/src/main/java/uniffi/greenfield5/

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" || exit 1; pwd)"
ANDROID_DIR="$(cd -- "$SCRIPT_DIR/.." || exit 1; pwd)"
REPO_ROOT="$(cd -- "$ANDROID_DIR/../.." || exit 1; pwd)"
CORE_DIR="$REPO_ROOT/core"
ANDROID_JAVA_DIR="$ANDROID_DIR/app/src/main/java"

printf 'SCRIPT_DIR=%s\n' "$SCRIPT_DIR"
printf 'ANDROID_DIR=%s\n' "$ANDROID_DIR"
printf 'REPO_ROOT=%s\n' "$REPO_ROOT"
printf 'CORE_DIR=%s\n' "$CORE_DIR"
printf 'ANDROID_JAVA_DIR=%s\n' "$ANDROID_JAVA_DIR"

# Ensure host cdylib exists for bindgen
if [ ! -f "$CORE_DIR/target/release/libgreenfield5_core.so" ] && [ ! -f "$CORE_DIR/target/release/libgreenfield5_core.dylib" ]; then
  printf 'Host cdylib not found, building...\n'
  (cd -- "$CORE_DIR" || exit 1; cargo build --release --locked)
fi

# The repository commits a pure-Kotlin fallback for builds without Rust.
# Real generation must replace it, never coexist with it.
rm -f "$ANDROID_JAVA_DIR/uniffi/greenfield5/greenfield5.kt"
rm -rf "$ANDROID_JAVA_DIR/uniffi/greenfield5_core"

printf 'Generating Kotlin bindings...\n'
if [ -f "$CORE_DIR/target/release/libgreenfield5_core.so" ]; then
  (cd -- "$CORE_DIR" || exit 1; cargo run --locked --bin uniffi-bindgen generate --library target/release/libgreenfield5_core.so --language kotlin --out-dir "$ANDROID_JAVA_DIR")
elif [ -f "$CORE_DIR/target/release/libgreenfield5_core.dylib" ]; then
  (cd -- "$CORE_DIR" || exit 1; cargo run --locked --bin uniffi-bindgen generate --library target/release/libgreenfield5_core.dylib --language kotlin --out-dir "$ANDROID_JAVA_DIR")
else
  printf 'ERROR: No host cdylib found for bindgen\n' >&2
  exit 1
fi

printf 'Generated files:\n'
find "$ANDROID_JAVA_DIR/uniffi" -type f -print | head -n 20 || true

GENERATED_KT="$ANDROID_JAVA_DIR/uniffi/greenfield5/greenfield5_core.kt"
if [ ! -f "$GENERATED_KT" ]; then
  printf 'ERROR: expected generated binding missing: %s\n' "$GENERATED_KT" >&2
  exit 1
fi
if ! grep -q '^package uniffi.greenfield5$' "$GENERATED_KT"; then
  printf 'ERROR: generated Kotlin package does not match app bridge imports\n' >&2
  head -n 40 "$GENERATED_KT" >&2 || true
  exit 1
fi

printf 'Done\n'
