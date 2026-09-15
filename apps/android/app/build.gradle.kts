import org.gradle.api.tasks.testing.logging.TestExceptionFormat
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "dev.greenfield5.app"
    compileSdk = libs.versions.compileSdk.get().toInt()

    defaultConfig {
        applicationId = "dev.greenfield5.app"
        minSdk = libs.versions.minSdk.get().toInt()
        targetSdk = libs.versions.targetSdk.get().toInt()
        versionCode = 1
        versionName = "0.1.0"
    }

    buildTypes {
        getByName("release") {
            // Release now enables R8 with keep rules for the UniFFI/JNA bridge.
            // The keep rules are build-proven: release build must keep UniFFI symbols.
            isMinifyEnabled = true
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    sourceSets {
        getByName("main") {
            // Rust cdylib built for Android ABIs lands in jniLibs/<abi>/libgreenfield5_core.so
            // via cargo-ndk. AGP picks it up automatically.
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    // AGP 9 built-in Kotlin: compiler options live under android.kotlin.
    kotlin {
        compilerOptions {
            jvmTarget = JvmTarget.fromTarget("17")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }
}

dependencies {
    // Compose libraries are versioned by the BOM (ADR-0006).
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    debugImplementation(libs.androidx.compose.ui.tooling)

    // UniFFI Kotlin bindings use JNA to call Rust cdylib.
    // Version pinned per UniFFI docs (JNA 5.12.0+ required).
    implementation("net.java.dev.jna:jna:5.14.0@aar")

    testImplementation(libs.junit)
    // For JVM unit tests that load host Rust library via JNA (bridge proof without Android NDK)
    testImplementation("net.java.dev.jna:jna:5.14.0")
}

tasks.withType<Test> {
    // Host Rust cdylib for JVM bridge-proof test: <repo>/core/target/release/libgreenfield5_core.so
    // Provide via JNA library path so System.loadLibrary and JNA can find it in CI.
    // Local dev without Rust toolchain will still work via fallback, but CI proof test will fail if not found.
    //
    // Resolve from rootProject, never by counting ".." from this module. The
    // Gradle build root is <repo>/apps/android and this module is one level
    // below it, so the previous "../../core/target/release" resolved to
    // <repo>/apps/core/target/release — a directory that cannot exist. Both
    // RealRustBridgeProofTest assertions then failed in CI (Stack run
    // 34995174223): System.load() had no library to load, and jna.library.path
    // pointed nowhere, so the generated bindings could not register with JNA
    // and coreVersion() fell back. The -Djna.library.path the workflow passes
    // reaches the Gradle JVM only; it is never forwarded to the test worker.
    val coreReleaseDir = rootProject.projectDir.parentFile.parentFile
        .resolve("core/target/release")
        .absolutePath
    val hostNativeLib = File(coreReleaseDir, System.mapLibraryName("greenfield5_core")).absolutePath
    systemProperty("greenfield5.native.lib.path", hostNativeLib)
    systemProperty("jna.library.path", coreReleaseDir)
    systemProperty("java.library.path", coreReleaseDir)
    environment("LD_LIBRARY_PATH", coreReleaseDir)
    environment("DYLD_LIBRARY_PATH", coreReleaseDir)
    // Ensure CI env is visible to tests
    environment("CI", System.getenv("CI") ?: "")
    environment("GITHUB_ACTIONS", System.getenv("GITHUB_ACTIONS") ?: "")

    // A failing bridge proof has to say WHY in the Gradle console log, because
    // that log is the only part of CI an agent or reviewer can still read:
    // raw Actions logs are unreachable from the sandbox and a check-run
    // annotation is capped at 4096 characters. Gradle's default short format
    // prints just the exception class and line ("java.lang.AssertionError at
    // RealRustBridgeProofTest.kt:42"), which hid the load error for several
    // CI cycles. FULL format prints the assertion message — and the test
    // already puts loadError and every library path into it — while
    // showStandardStreams adds the diagnostics the test prints itself.
    // Neither setting can turn a failing test into a passing one.
    testLogging {
        exceptionFormat = TestExceptionFormat.FULL
        showStandardStreams = true
    }
}
