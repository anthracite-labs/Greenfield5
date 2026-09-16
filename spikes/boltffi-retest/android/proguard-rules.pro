# Candidate JNI names and native handle wrappers must remain reachable. No JNA.
-keep class dev.greenfield5.bolt.** { *; }
-keepclasseswithmembernames class * { native <methods>; }

# The minified *instrumentation* APK (testBuildType=release) drags in androidx.test and
# Guava internals whose compile-only annotation classes are absent at runtime. R8 needs
# them for analysis, the JVM never loads them, so `-dontwarn` is the documented remedy:
# run 35119746524's release phase failed assembly with
# "Missing classes detected while running R8 ... com.google.errorprone.annotations.CanIgnoreReturnValue
# (referenced from: androidx.test.internal.util.Checks.checkNotNull)". This cannot mask the
# failure the minified phase exists to catch - the generated bridge is kept by the rules
# above and every phase exercises it at runtime, where a stripped class would surface as
# a NoClassDefFoundError rather than a warning.
-dontwarn com.google.errorprone.annotations.**
