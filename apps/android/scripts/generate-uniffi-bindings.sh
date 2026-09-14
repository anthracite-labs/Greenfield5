#!/usr/bin/env bash
set -euo pipefail

# Generates Kotlin bindings for Greenfield5 core (UniFFI 0.32.1)
# Called from CI after Rust Android libs built.
# Inputs: core/target/release/libgreenfield5_core.so (host)
# Outputs: apps/android/app/src/main/java/uniffi/greenfield5/

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CORE_DIR="$ROOT/../../core"
ANDROID_JAVA_DIR="$ROOT/app/src/main/java"

echo "ROOT=$ROOT"
echo "CORE_DIR=$CORE_DIR"
echo "ANDROID_JAVA_DIR=$ANDROID_JAVA_DIR"

# Ensure host cdylib exists for bindgen
if [ ! -f "$CORE_DIR/target/release/libgreenfield5_core.so" ]; then
  echo "Host cdylib not found, building..."
  (cd "$CORE_DIR" && cargo build --release)
fi

echo "Generating Kotlin bindings..."
(cd "$CORE_DIR" && cargo run --bin uniffi-bindgen generate --library target/release/libgreenfield5_core.so --language kotlin --out-dir "$ANDROID_JAVA_DIR")

echo "Generated files:"
find "$ANDROID_JAVA_DIR/uniffi" -type f | head -n 20

echo "Done"
