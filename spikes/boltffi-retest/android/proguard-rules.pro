# Candidate JNI names and native handle wrappers must remain reachable. No JNA.
-keep class dev.greenfield5.bolt.** { *; }
-keepclasseswithmembernames class * { native <methods>; }
