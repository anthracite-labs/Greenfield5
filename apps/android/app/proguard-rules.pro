# Greenfield5 release keep rules — UniFFI/JNA bridge (Issue #15).
#
# The Rust core is exposed via UniFFI which generates Kotlin bindings that
# use JNA to call the cdylib. R8 must not strip:
# - the generated UniFFI Kotlin package and its JNA glue
# - JNA itself
# - the System.loadLibrary call site in our wrapper
#
# These rules are build-proven: release build with isMinifyEnabled=true must
# keep the symbols, otherwise the app crashes on startup when loading the Rust
# library. Verified by assembleRelease in CI (stack.yml).

# Keep all generated UniFFI bindings for greenfield5.
# The generated package is exactly `uniffi.greenfield5` — asserted by the
# Android job in stack.yml, which fails if uniffi-bindgen ignores
# core/uniffi.toml's package_name and produces a `uniffi.greenfield5_core`
# package instead. No rule is needed for the ignored-default name.
-keep class uniffi.greenfield5.** { *; }
# The bridge loader is dev.greenfield5.app.bridge.GreenfieldRustBridge; this
# wildcard is the rule that actually keeps it. Keep it after any package move.
-keep class dev.greenfield5.app.bridge.** { *; }

# Keep JNA
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }

# JNA references java.awt on desktop JVM, which does not exist on Android.
# R8 needs dontwarn for those missing classes, otherwise minifyReleaseWithR8 fails.
# Verified via CI: run 34960598085 failed with Missing class java.awt.Component
# referenced from com.sun.jna.Native$AWT. Adding dontwarn allows R8 to proceed.
-dontwarn java.awt.*
-dontwarn com.sun.jna.awt.*
-dontwarn com.sun.jna.Native$AWT

# Keep native methods and JNI entry points
-keepclasseswithmembernames class * {
    native <methods>;
}

# UniFFI generates classes with @Suppress warnings and uses reflection for
# cleaner; keep those
-keepattributes *Annotation*,InnerClasses,EnclosingMethod
-keepattributes Signature

# Do not obfuscate JNA callback interfaces
-keep interface com.sun.jna.Callback { *; }
-keep class com.sun.jna.Structure { *; }

# AGP 9 fails the build if a declared proguard file is missing
# (android.proguard.failOnMissingFiles), so this file exists and is declared.
