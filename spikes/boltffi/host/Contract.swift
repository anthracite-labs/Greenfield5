import Foundation
import Testing

@Suite("Bolt native contract") struct BoltContract {
    @Test func contract() throws {
        #expect(coreVersion() == "0.1.0")
        let sender = GreenfieldSession(role: .sender, mode: .internet)
        #expect(sender.stateCode() == 0)
        #expect(try sender.apply(command: .startPairing) == .awaitingPeer)
        #expect(try sender.sendCommand(commandCode: 2) == 2)
        #expect(throws: BridgeError.self) { try sender.sendCommand(commandCode: 2) }
        #expect(try sender.sendCommand(commandCode: 3) == 3)
        #expect(sender.viewerApproved())
        #expect(throws: BridgeError.self) { try sender.sendCommand(commandCode: 255) }
        let viewer = GreenfieldSession(role: .viewer, mode: .local)
        #expect(try viewer.sendCommand(commandCode: 1) == 2)
        #expect(try viewer.sendCommand(commandCode: 4) == 3)
        let input = LayoutProbe(flag: 7, wide: 0x1122334455667788, short: 0x3344, text: "layout")
        #expect(roundTrip(value: input) == input)
        print("BOLT_PROOF version=0.1.0 sender=PASS viewer=PASS layout=PASS")
    }
    @Test func asyncSuccess() async throws {
        let probe = AsyncProbe()
        probe.release()
        #expect(try await probe.waitValue(sequence: 42, fail: false) == 42)
        #expect(probe.active() == 0)
    }
    @Test func boundedBatch() {
        let probe = EventProbe()
        let stream = probe.eventsBatch()
        #expect(probe.produce(count: 100) == 8)
        #expect(stream.popBatch(maxCount: 100) == Array(0..<8).map(UInt32.init))
        #expect(probe.dropped() == 92)
        probe.stop()
        stream.unsubscribe()
    }
}
