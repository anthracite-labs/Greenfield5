# Greenfield5 release keep rules.
#
# Intentionally empty at the skeleton stage (ADR-0006): nothing is minified
# yet. The future native-to-Rust bridge (JNI/UniFFI symbols) will need keep
# rules; they arrive with the bridge issue, reviewed together with it.
#
# AGP 9 fails the build if a declared proguard file is missing
# (android.proguard.failOnMissingFiles), so this file exists and is declared.
