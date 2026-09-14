// Top-level build file. Versions live in gradle/libs.versions.toml; the pins
// and their evidence are recorded in docs/decisions/0006-application-stack.md.
//
// AGP 9 note: Kotlin support is built into AGP 9 (no org.jetbrains.kotlin.android
// plugin). The Compose compiler plugin carries the Kotlin (KGP) version and
// upgrades AGP's built-in KGP through normal classpath resolution — the same
// shape Google's official compose-samples use on AGP 9.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.kotlin.compose) apply false
}
