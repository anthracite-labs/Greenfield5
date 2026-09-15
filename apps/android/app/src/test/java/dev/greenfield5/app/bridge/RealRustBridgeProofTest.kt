package dev.greenfield5.app.bridge

import org.junit.Assert.*
import org.junit.Test

/**
 * Proves Android JVM tests execute against REAL Rust/UniFFI bindings,
 * not the pure-Kotlin fallback stub.
 *
 * This test is the CI-only proof for Issue #15 criterion #3:
 * - It MUST fail if the fallback/stub path is used in CI
 * - It MUST NOT accept System.loadLibrary failure silently
 * - It MUST prove a call crosses into Rust via generated UniFFI Kotlin bindings
 *
 * How it proves real Rust:
 * 1. Checks that the Rust native library was actually loaded (isLibraryLoaded true)
 * 2. Checks that coreVersion() returns the real crate version (0.1.0), not fallback (0.1.0-fallback) or stub
 * 3. Drives a full sender journey through Rust (via UniFFI) and asserts expected state codes
 * 4. Fails closed if library not loaded when in CI (GITHUB_ACTIONS or CI env set)
 *
 * Local dev without Rust toolchain:
 * - When CI env not set and library not loaded, test is skipped via Assume (allows local fallback)
 * - When library is present locally (cargo build --release), test will still prove real Rust
 */
class RealRustBridgeProofTest {

    @Test
    fun `real Rust library must be loaded in CI and version must be real`() {
        val isCI = System.getenv("CI") != null || System.getenv("GITHUB_ACTIONS") != null
        val libLoaded = GreenfieldRustBridge.isLibraryLoaded()
        val loadError = GreenfieldRustBridge.loadError()
        val version = GreenfieldRustBridge.coreVersion()

        // Always log for diagnostics
        println("RealRustBridgeProof: isCI=$isCI, libLoaded=$libLoaded, version=$version, loadError=$loadError")
        println("jna.library.path=${System.getProperty("jna.library.path")}")
        println("java.library.path=${System.getProperty("java.library.path")}")
        println("LD_LIBRARY_PATH=${System.getenv("LD_LIBRARY_PATH")}")

        if (isCI) {
            // In CI, we MUST have real Rust library - fail if fallback used
            assertTrue(
                "In CI, Rust native library must be loaded. loadError=$loadError, jna.library.path=${System.getProperty("jna.library.path")}",
                libLoaded
            )
            assertFalse("In CI, version must not be fallback, got $version", version.contains("fallback"))
            assertFalse("In CI, version must not be stub, got $version", version.contains("stub"))
            // Real version from Cargo.toml is 0.1.0 - must be exact or contain 0.1.0 and not be fallback
            assertTrue("In CI, version must contain 0.1.0 and be real, got $version", version.contains("0.1.0") && version == "0.1.0")
        } else {
            // Locally, allow fallback but still require non-empty
            assertTrue("Version must be non-empty", version.isNotEmpty())
            if (!libLoaded) {
                println("Local dev without Rust - skipping strict real-Rust assertions")
                return
            }
        }

        // If we reach here, library is loaded - prove call crosses into Rust via UniFFI
        // Real Rust core should handle sender journey correctly
        val senderCodes = GreenfieldRustBridge.runSenderJourney()
        assertEquals(
            "Sender journey via real Rust must be [0,1,2,3,3]",
            listOf(0u.toUByte(), 1u.toUByte(), 2u.toUByte(), 3u.toUByte(), 3u.toUByte()),
            senderCodes
        )

        val viewerCodes = GreenfieldRustBridge.runViewerJourney()
        assertEquals(
            "Viewer journey via real Rust must be [0,2,3,3]",
            listOf(0u.toUByte(), 2u.toUByte(), 3u.toUByte(), 3u.toUByte()),
            viewerCodes
        )

        // Additional proof: create session from codes (u8 wire codes) - this exercises Rust's from_code logic
        val session = GreenfieldRustBridge.createSessionFromCodes(0u, 2u) // sender, internet
        assertEquals(0u.toUByte(), session.stateCode())
    }

    @Test
    fun `core version from Rust must match Cargo toml version`() {
        val isCI = System.getenv("CI") != null || System.getenv("GITHUB_ACTIONS") != null
        if (!GreenfieldRustBridge.isLibraryLoaded() && !isCI) {
            println("Skipping version match test - no Rust lib locally")
            return
        }
        val version = GreenfieldRustBridge.coreVersion()
        // This will fail if stub is used in CI
        if (isCI) {
            assertEquals("Real Rust version must be exactly 0.1.0 from Cargo.toml", "0.1.0", version)
        }
    }
}
