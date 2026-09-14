import Foundation

/// Real native↔Rust bridge for iOS.
///
/// - When the Rust XCFramework is present (built via cargo + XCFramework script),
///   this wrapper delegates to the real UniFFI-generated Swift bindings
///   (package `greenfield5` with C header + modulemap).
/// - When the XCFramework is absent (local builds without Rust toolchain),
///   it uses the pure-Swift stub in `Generated/greenfield5.swift` which mirrors
///   the same API and session logic as Rust.
///
/// The narrow API ensures UI code depends on this wrapper only, never on
/// transport internals. R8/JNI keep rules are Android-specific; iOS linking
/// is handled via XCFramework.

public struct GreenfieldRustBridge {
    public static func getCoreVersion() -> String {
        // Calls UniFFI-generated coreVersion() — stub or real.
        return coreVersion()
    }

    public static func isRustLibraryPresent() -> Bool {
        // In real integration, we can check if XCFramework symbols are linked.
        // For stub, we detect version string containing "stub".
        let v = getCoreVersion()
        return !v.contains("stub")
    }

    public static func createSenderSession(mode: ConnectionMode) -> GreenfieldSession {
        return GreenfieldSession.new(role: .sender, mode: mode)
    }

    public static func createViewerSession(mode: ConnectionMode) -> GreenfieldSession {
        return GreenfieldSession.new(role: .viewer, mode: mode)
    }

    public static func runSenderJourney() throws -> [UInt8] {
        let session = createSenderSession(mode: .internet)
        var codes: [UInt8] = []
        codes.append(session.stateCode())
        codes.append(try session.sendCommand(commandCode: 0)) // StartPairing
        codes.append(try session.sendCommand(commandCode: 2)) // PeerRequestedJoin
        codes.append(try session.sendCommand(commandCode: 3)) // ApproveViewer
        codes.append(session.stateCode())
        return codes
    }

    public static func runViewerJourney() throws -> [UInt8] {
        let session = createViewerSession(mode: .local)
        var codes: [UInt8] = []
        codes.append(session.stateCode())
        codes.append(try session.sendCommand(commandCode: 1)) // RequestJoin
        codes.append(try session.sendCommand(commandCode: 4)) // ApprovalReceived
        codes.append(session.stateCode())
        return codes
    }

}
