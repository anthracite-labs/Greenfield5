import Testing

@testable import Greenfield5

/// Proves iOS can call Rust core through the UniFFI bridge (Issue #15).
///
/// CI must generate and link the real Rust XCFramework before these tests.
/// The exact version assertion rejects the committed no-toolchain placeholder;
/// a local stub-only build is not native execution evidence (PR #18).
@Suite("Rust bridge")
struct BridgeTests {
    @Test("core version is exactly 0.1.0")
    func coreVersionIsExact() {
        let v = GreenfieldRustBridge.getCoreVersion()
        #expect(v == "0.1.0")
    }

    @Test("sender journey reaches active via typed API")
    func senderJourneyTyped() throws {
        let session = GreenfieldSession(role: .sender, mode: .internet)
        #expect(try session.apply(command: .startPairing) == .awaitingPeer)
        #expect(try session.apply(command: .peerRequestedJoin) == .awaitingApproval)
        #expect(session.viewerApproved() == false)
        #expect(try session.apply(command: .approveViewer) == .active)
        #expect(session.viewerApproved() == true)
    }

    @Test("viewer journey reaches active")
    func viewerJourneyTyped() throws {
        let session = GreenfieldSession(role: .viewer, mode: .local)
        #expect(try session.apply(command: .requestJoin) == .awaitingApproval)
        #expect(try session.apply(command: .approvalReceived) == .active)
    }

    @Test("sender journey via u8 wire codes")
    func senderJourneyViaCodes() throws {
        let codes = try GreenfieldRustBridge.runSenderJourney()
        // Expected: Idle(0), AwaitingPeer(1), AwaitingApproval(2), Active(3), Active(3)
        #expect(codes == [0, 1, 2, 3, 3])
    }

    @Test("viewer journey via u8 wire codes")
    func viewerJourneyViaCodes() throws {
        let codes = try GreenfieldRustBridge.runViewerJourney()
        #expect(codes == [0, 2, 3, 3])
    }

    @Test("one-viewer rule preserved")
    func oneViewerRule() throws {
        let session = GreenfieldSession(role: .sender, mode: .direct)
        _ = try session.apply(command: .startPairing)
        _ = try session.apply(command: .peerRequestedJoin)
        #expect(throws: BridgeError.self) {
            try session.apply(command: .peerRequestedJoin)
        }
    }

    @Test("fromCodes rejects unknown")
    func fromCodesRejectsUnknown() {
        #expect(throws: BridgeError.self) {
            try GreenfieldSession.fromCodes(roleCode: 9, modeCode: 0)
        }
        #expect(throws: BridgeError.self) {
            try GreenfieldSession.fromCodes(roleCode: 0, modeCode: 42)
        }
    }
}
