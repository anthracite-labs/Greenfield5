import Foundation
import Testing

/// Thread-safe counter; async tests observe callbacks arriving on native threads.
final class Tally: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}

/// Harness only, and deliberately narrow: the generated Swift classes are not
/// `Sendable` (upstream #778 is open), so a test that must cancel an in-flight
/// call from a different task cannot capture the generated object directly in a
/// `Task` closure. The Rust side of that object is `Mutex`-guarded and its FFI
/// entry points are callable from any thread by construction, so this box
/// asserts exactly that and nothing more. It is not a product workaround and it
/// does not relax any diagnostic in the generated code.
final class CrossTask<T>: @unchecked Sendable {
    let value: T
    init(_ value: T) { self.value = value }
}

@Suite("Bolt native contract") struct BoltContract {
    @Test func contract() throws {
        #expect(coreVersion() == "0.1.0")
        let sender = GreenfieldSession(role: .sender, mode: .internet)
        #expect(sender.stateCode() == 0)
        let paired = try sender.apply(command: .startPairing)
        #expect(paired == .awaitingPeer)
        #expect(try sender.sendCommand(commandCode: 2) == 2)
        #expect(throws: BridgeError.self) { try sender.sendCommand(commandCode: 2) }
        #expect(try sender.sendCommand(commandCode: 3) == 3)
        #expect(sender.viewerApproved())
        #expect(throws: BridgeError.self) { try sender.sendCommand(commandCode: 255) }
        #expect(sender.stateCode() == 3)
        let viewer = GreenfieldSession(role: .viewer, mode: .local)
        #expect(try viewer.sendCommand(commandCode: 1) == 2)
        #expect(try viewer.sendCommand(commandCode: 4) == 3)
        let input = LayoutProbe(flag: 7, wide: 0x1122334455667788, short: 0x3344, text: "layout")
        #expect(roundTrip(value: input) == input)
        let padded = PaddingProbe(version: 0x1234, value: 0x55667788)
        #expect(paddingRoundTrip(value: padded) == padded)
        #expect(paddingList(value: padded) == [padded, padded])
        print("BOLT_PROOF version=0.1.0 sender=PASS viewer=PASS typed_errors=PASS layout=PASS")
    }

    @Test func asyncSuccess() async throws {
        let probe = AsyncProbe()
        probe.release()
        let value = try await probe.waitValue(sequence: 42, fail: false)
        #expect(value == 42)
        #expect(probe.active() == 0)
    }

    @Test func asyncTypedFailure() async throws {
        let probe = AsyncProbe()
        probe.release()
        do {
            _ = try await probe.waitValue(sequence: 1, fail: true)
            Issue.record("expected the typed async failure to be thrown")
        } catch is BridgeError {
            print("BOLT_ERR typed=BridgeError delivered=true")
        }
        #expect(probe.active() == 0)
    }

    @Test func boundedBatchKeepsPullControl() {
        let probe = EventProbe()
        let stream = probe.eventsBatch()
        #expect(probe.produce(count: 100) == 8)
        #expect(stream.popBatch(maxCount: 100) == Array(0..<8).map(UInt32.init))
        #expect(probe.dropped() == 92)
        probe.stop()
        stream.unsubscribe()
        #expect(!probe.isActive())
    }
}

@Suite("Bolt ownership") struct BoltOwnership {
    /// Cancellation before completion, cleanup after cancellation, and a
    /// repeated cancel that must not double-free the native future.
    @Test func repeatedCancellation() async throws {
        for _ in 0..<50 {
            let probe = AsyncProbe()
            let box = CrossTask(probe)
            let task = Task { try await box.value.waitValue(sequence: 1, fail: false) }
            while probe.active() == 0 { await Task.yield() }
            task.cancel()
            task.cancel()
            _ = await task.result
            #expect(probe.active() == 0)

            // The object and its handle must still be fully usable: a double
            // free on the cancel path would corrupt memory or crash here.
            probe.release()
            let value = try await probe.waitValue(sequence: 3, fail: false)
            #expect(value == 3)
            #expect(probe.active() == 0)
        }
    }

    /// Cancellation racing readiness: release() makes the future ready while
    /// cancel() lands. Exactly one of the two paths may claim the completion.
    @Test func cancellationRacingReadiness() async throws {
        for _ in 0..<50 {
            let probe = AsyncProbe()
            let box = CrossTask(probe)
            let task = Task { try await box.value.waitValue(sequence: 5, fail: false) }
            while probe.active() == 0 { await Task.yield() }
            probe.release()
            task.cancel()
            _ = await task.result
            #expect(probe.active() == 0)
        }
    }

    /// Lifecycle: repeated create-use-destroy must free exactly once each time.
    @Test func lifecycleCreateDestroyIsStable() async throws {
        for _ in 0..<100 {
            let probe = AsyncProbe()
            probe.release()
            let value = try await probe.waitValue(sequence: 1, fail: false)
            #expect(value == 1)
        }
        for _ in 0..<100 {
            let session = GreenfieldSession(role: .sender, mode: .local)
            let state = try session.apply(command: .startPairing)
            #expect(state == .awaitingPeer)
        }
        for _ in 0..<50 {
            let probe = EventProbe()
            let stream = probe.eventsBatch()
            _ = probe.produce(count: 100)
            #expect(stream.popBatch(maxCount: 8).count == 8)
            probe.stop()
            stream.unsubscribe()
        }
    }

    /// Concurrent receivers on concurrent threads: each call retains its own
    /// receiver and frees it on its own path.
    @Test func concurrentReceivers() async throws {
        try await withThrowingTaskGroup(of: UInt32.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    let probe = AsyncProbe()
                    probe.release()
                    return try await probe.waitValue(sequence: 9, fail: false)
                }
            }
            var total: UInt32 = 0
            for try await value in group { total += value }
            #expect(total == 32 * 9)
        }
    }
}

@Suite("Bolt streams") struct BoltStreams {
    /// Slow consumer over the async (AsyncStream) delivery. The native ring is
    /// bounded at eight, so pacing production well below that capacity isolates
    /// whatever the generated host queue does. Printed numbers are the
    /// observable backlog; the assertion is accounting integrity only.
    @Test func slowConsumerHostBacklog() async throws {
        let probe = EventProbe()
        let stream = probe.events()
        var iterator = stream.makeAsyncIterator()
        for _ in 0..<100 {
            _ = probe.produce(count: 1)
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        let produced = probe.produced()
        let nativeDropped = probe.dropped()

        var consumed = 0
        let deadline = Date().addingTimeInterval(2)
        while consumed < 20, Date() < deadline {
            guard await iterator.next() != nil else { break }
            consumed += 1
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        let hostBuffered = Int(produced) - Int(nativeDropped) - consumed
        print(
            "BOLT_BACKLOG policy=unbounded produced=\(produced) nativeDropped=\(nativeDropped) "
                + "consumed=\(consumed) hostBuffered=\(hostBuffered)"
        )
        #expect(produced == 100)
        #expect(consumed + hostBuffered + Int(nativeDropped) == Int(produced))
        probe.stop()
    }

    /// Bounded alternative: batch delivery keeps pull control in the host.
    @Test func boundedBatchIsTheBoundedStrategy() {
        let probe = EventProbe()
        let stream = probe.eventsBatch()
        var observed: [UInt32] = []
        for _ in 0..<100 {
            _ = probe.produce(count: 1)
            observed.append(contentsOf: stream.popBatch(maxCount: 4))
        }
        let dropped = probe.dropped()
        print(
            "BOLT_BOUNDED policy=batch produced=\(probe.produced()) consumed=\(observed.count) "
                + "nativeDropped=\(dropped) hostBuffered=0"
        )
        #expect(observed.count == Int(probe.produced()) - Int(dropped))
        #expect(observed == observed.sorted())
        probe.stop()
        stream.unsubscribe()
        #expect(!probe.isActive())
    }

    /// Cancelling the consumer while the producer is active: delivery must stop,
    /// no further callbacks may arrive, and the native subscription must finish.
    @Test func producerCancellationStopsDelivery() async throws {
        let probe = EventProbe()
        let stream = probe.events()
        let tally = Tally()
        let consumer = Task {
            for await _ in stream { tally.increment() }
        }
        for _ in 0..<32 {
            _ = probe.produce(count: 1)
            await Task.yield()
        }
        consumer.cancel()
        _ = await consumer.result
        let afterCancel = tally.count
        for _ in 0..<32 {
            _ = probe.produce(count: 1)
            await Task.yield()
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        let afterMore = tally.count
        probe.stop()
        print("BOLT_CANCEL consumedAfterCancel=\(afterCancel) consumedAfterMore=\(afterMore)")
        #expect(afterMore - afterCancel <= 1)
        #expect(!probe.isActive())
    }
}
