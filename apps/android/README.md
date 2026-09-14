# Greenfield5 — Android shell

Jetpack Compose shell for Greenfield5 (Issue #13, ADR-0006). UI-only by
design: all session/pairing/protocol logic will live in the shared Rust
core (`core/`) and reach this app exclusively through the native-to-core
seam when the bridge follow-up lands.

## Stack (pinned — evidence in ADR-0006)

- AGP **9.4.0** with **built-in Kotlin** (no `org.jetbrains.kotlin.android`
  plugin; `android.kotlin { compilerOptions { ... } }` instead).
- Kotlin / Compose compiler plugin **2.4.20**
  (`org.jetbrains.kotlin.plugin.compose`).
- Gradle wrapper **9.6.1** (`distributionSha256Sum` pinned in
  `gradle/wrapper/gradle-wrapper.properties`).
- Compose BOM **2026.08.00**, `activity-compose` **1.13.0**.
- `compileSdk`/`targetSdk` **37** (Android 17), `minSdk` **29**
  (Android 10, PRODUCT.md §11). JDK **17**.

## Layout

- `app/src/main/java/dev/greenfield5/app/` — sources (AGP-standard `java`
  source dir holds Kotlin too):
  - `MainActivity.kt` — single-activity Compose host, edge-to-edge.
  - `ui/AppNavigation.kt` — `AppScreen` / `HomeAction` model and the single
    navigation rule `destinationFor()`, mirrored by the iOS shell.
  - `ui/Greenfield5App.kt` — state-based screen switching.
  - `ui/HomeScreen.kt` — the two primary actions ("Share My Screen",
    "View a Screen").
  - `ui/SenderScreen.kt`, `ui/ViewerScreen.kt` — role entry-point
    placeholders.
  - `ui/theme/` — Material 3 theme, placeholder palette, dynamic color.
- `app/src/test/java/.../AppNavigationTest.kt` — JVM unit tests for the
  navigation rule.
- `app/src/main/res/` — strings, platform themes (day/night), vector
  adaptive launcher icon.

## Building and testing

```sh
./gradlew testDebugUnitTest assembleDebug
```

Requires JDK 17 + Android SDK 37; the Gradle wrapper bootstraps Gradle
itself. CI runs this in `.github/workflows/stack.yml`.

## Explicitly not here yet (Issue #13 follow-ups)

- Native-to-Rust bridge (UniFFI or pinned FFI) — follow-up 1, including
  R8/JNI keep rules (`proguard-rules.pro` is intentionally empty).
- MediaProjection capture, foreground service, and the permissions flow.
- MoQ/Iroh transport, pairing UX, join codes; note the Android 17
  local-network restriction recorded in `docs/MEMORY.md` (targetSdk 37 +
  Local mode will need `ACCESS_LOCAL_NETWORK` handling).
