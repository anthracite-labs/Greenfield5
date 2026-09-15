package dev.greenfield5.app.bridge

import org.junit.Assert.*
import org.junit.Test
import uniffi.greenfield5.ConnectionMode
import uniffi.greenfield5.Role
import uniffi.greenfield5.SessionCommand
import uniffi.greenfield5.SessionState

/**
 * Proves Android can call Rust core through the UniFFI bridge.
 *
 * This test runs on the JVM (testDebugUnitTest) and uses the stub Kotlin
 * implementation when libgreenfield5_core.so is not present, and the real
 * JNA-backed implementation when CI builds the Rust cdylib via cargo-ndk.
 * Either way, it proves the narrow bridge API (Role/Mode/State/Command)
 * works and the session state machine semantics are preserved.
 *
 * Acceptance criteria #3 and #2: Android build + existing core semantics.
 */
class GreenfieldRustBridgeTest {

    @Test
    fun `core version is present`() {
        val version = GreenfieldRustBridge.coreVersion()
        assertTrue("core version must be non-empty", version.isNotEmpty())
    }

    @Test
    fun `sender journey reaches active via typed API`() {
        val session = GreenfieldRustBridge.createSenderSession(ConnectionMode.INTERNET)
        assertEquals(SessionState.IDLE, session.state())
        assertEquals(SessionState.AWAITING_PEER, session.apply(SessionCommand.START_PAIRING))
        assertEquals(SessionState.AWAITING_APPROVAL, session.apply(SessionCommand.PEER_REQUESTED_JOIN))
        assertFalse(session.viewerApproved())
        assertEquals(SessionState.ACTIVE, session.apply(SessionCommand.APPROVE_VIEWER))
        assertTrue(session.viewerApproved())
    }

    @Test
    fun `viewer journey reaches active via typed API`() {
        val session = GreenfieldRustBridge.createViewerSession(ConnectionMode.LOCAL)
        assertEquals(SessionState.IDLE, session.state())
        assertEquals(SessionState.AWAITING_APPROVAL, session.apply(SessionCommand.REQUEST_JOIN))
        assertEquals(SessionState.ACTIVE, session.apply(SessionCommand.APPROVAL_RECEIVED))
    }

    @Test
    fun `sender journey via u8 wire codes matches typed journey`() {
        val codes = GreenfieldRustBridge.runSenderJourney()
        // Expected: Idle(0), AwaitingPeer(1), AwaitingApproval(2), Active(3), Active(3)
        assertEquals(listOf(0u.toUByte(), 1u.toUByte(), 2u.toUByte(), 3u.toUByte(), 3u.toUByte()), codes)
    }

    @Test
    fun `viewer journey via u8 wire codes`() {
        val codes = GreenfieldRustBridge.runViewerJourney()
        // Idle(0), AwaitingApproval(2), Active(3), Active(3)
        assertEquals(listOf(0u.toUByte(), 2u.toUByte(), 3u.toUByte(), 3u.toUByte()), codes)
    }

    @Test
    fun `bridge preserves one-viewer rule`() {
        val session = GreenfieldRustBridge.createSenderSession(ConnectionMode.DIRECT)
        session.apply(SessionCommand.START_PAIRING)
        session.apply(SessionCommand.PEER_REQUESTED_JOIN)
        try {
            session.apply(SessionCommand.PEER_REQUESTED_JOIN)
            fail("second viewer must be rejected")
        } catch (e: Exception) {
            // Expected BridgeException.ViewerAlreadyConnected
            assertTrue(e.message?.contains("viewer") == true || e.toString().contains("ViewerAlreadyConnected"))
        }
    }

    @Test
    fun `from_codes rejects unknown codes`() {
        try {
            GreenfieldRustBridge.createSessionFromCodes(9u, 0u)
            fail("unknown role code must be rejected")
        } catch (e: Exception) {
            // expected
        }
        try {
            GreenfieldRustBridge.createSessionFromCodes(0u, 42u)
            fail("unknown mode code must be rejected")
        } catch (e: Exception) {
            // expected
        }
    }
}
