package dev.greenfield5.app.bridge

import uniffi.greenfield5.BridgeError
import uniffi.greenfield5.ConnectionMode
import uniffi.greenfield5.GreenfieldSession
import uniffi.greenfield5.Role
import uniffi.greenfield5.SessionCommand
import uniffi.greenfield5.SessionState
import uniffi.greenfield5.coreVersion

/**
 * Real native↔Rust bridge for Android.
 *
 * - Tries to load the Rust cdylib `libgreenfield5_core.so` built via cargo-ndk.
 * - Delegates to UniFFI-generated bindings (package `uniffi.greenfield5`) when
 *   the library is present; falls back to pure-Kotlin stub implementation
 *   (same file, different build) when running JVM unit tests without NDK.
 * - Preserves narrow API: UI code depends on this wrapper, not on transport
 *   internals or JNA details.
 *
 * R8 keep rules in proguard-rules.pro ensure UniFFI/JNA symbols are not
 * stripped in release builds (build-proven via assembleRelease).
 */
object GreenfieldRustBridge {
    private var libraryLoaded: Boolean = false
    private var loadError: Throwable? = null

    init {
        try {
            // Loads libgreenfield5_core.so from jniLibs/<abi>/
            System.loadLibrary("greenfield5_core")
            libraryLoaded = true
        } catch (e: Throwable) {
            // Expected in JVM unit tests or when NDK build not yet run.
            // Stub Kotlin implementation will still work.
            libraryLoaded = false
            loadError = e
        }
    }

    fun isLibraryLoaded(): Boolean = libraryLoaded
    fun loadError(): Throwable? = loadError

    fun coreVersion(): String = try {
        coreVersion()
    } catch (e: Throwable) {
        "0.1.0-fallback"
    }

    fun createSenderSession(mode: ConnectionMode): GreenfieldSession {
        return GreenfieldSession.new(Role.SENDER, mode)
    }

    fun createViewerSession(mode: ConnectionMode): GreenfieldSession {
        return GreenfieldSession.new(Role.VIEWER, mode)
    }

    fun createSessionFromCodes(roleCode: UByte, modeCode: UByte): GreenfieldSession {
        return GreenfieldSession.fromCodes(roleCode, modeCode)
    }

    /**
     * Minimal proof that Android can call Rust core through real bridge:
     * creates a sender session, drives it to Active, returns state codes.
     * Used by unit tests and UI debug screen.
     */
    fun runSenderJourney(): List<UByte> {
        val session = createSenderSession(ConnectionMode.INTERNET)
        val codes = mutableListOf<UByte>()
        codes.add(session.stateCode())
        codes.add(session.sendCommand(0u)) // StartPairing -> AwaitingPeer
        codes.add(session.sendCommand(2u)) // PeerRequestedJoin -> AwaitingApproval
        codes.add(session.sendCommand(3u)) // ApproveViewer -> Active
        codes.add(session.stateCode())
        return codes
    }

    fun runViewerJourney(): List<UByte> {
        val session = createViewerSession(ConnectionMode.LOCAL)
        val codes = mutableListOf<UByte>()
        codes.add(session.stateCode())
        codes.add(session.sendCommand(1u)) // RequestJoin -> AwaitingApproval
        codes.add(session.sendCommand(4u)) // ApprovalReceived -> Active
        codes.add(session.stateCode())
        return codes
    }
}
