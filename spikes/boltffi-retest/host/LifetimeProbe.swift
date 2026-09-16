import Foundation
import Testing

/// Registry of live mock futures, keyed by the token value the generated runtime
/// sees as its opaque handle.
final class MockNativeFutureRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var futures: [UInt: MockNativeFuture] = [:]
    private var nextToken: UInt = 0x1000

    func register(_ future: MockNativeFuture) -> UInt {
        lock.lock()
        defer { lock.unlock() }
        nextToken += 8
        futures[nextToken] = future
        return nextToken
    }
}

/// Model of the Rust future contract (`boltffi_core/src/runtime/future.rs`), used
/// to drive the *generated* async runtime without a native library.
///
/// It mirrors the real ABI:
///
///  * `poll`, `cancel` and `complete` only *borrow* the handle
///    (`Arc::from_raw` + `mem::forget` in `RustFutureHandleAccess`), while `free`
///    *consumes* it (`consume_future`) and is the only call that invalidates it;
///  * `poll` may invoke the Swift continuation callback synchronously from inside
///    its own frame - the real runtime does that for a ready future, for a
///    cancelled one, and from `store_continuation` when it displaces a parked
///    continuation - and a native wake delivers `MaybeReady` from another thread;
///  * a second poll while a continuation is parked displaces the older one
///    (`Policy::displaced()` = `Ready`) instead of replacing it silently.
///
/// So the model knows whether a native call or a native-delivered callback was on
/// the stack when `free` ran, which is exactly the difference between "the handle
/// is owned" and "the handle happens to still be usable". Violations are
/// recorded, never raised: a probe that crashes cannot report what it saw.
final class MockNativeFuture: @unchecked Sendable {
    static let registry = MockNativeFutureRegistry()
    /// Completion value reported by `complete`.
    static let expectedValue: UInt32 = 0x5eed

    /// Signal the generated runtime's callback receives: 0 = Ready, 1 = MaybeReady
    /// (`RustFuturePoll` is `#[repr(i8)]`).
    enum Signal: Int8 {
        case ready = 0
        case maybeReady = 1
    }

    /// Assigned by `make`, so `init` never passes a half-initialised `self` to the
    /// registry.
    private var token: UInt = 0
    private let readyAfterPolls: Int
    private let wakeOnceWhenParked: Bool
    private let lock = NSLock()

    private var freed = false
    private var freeCount = 0
    private var pollCount = 0
    private var cancelCount = 0
    private var completeCount = 0
    private var displacements = 0
    private var nativeDepth = 0
    private var callbackDepth = 0
    private var violations: [String] = []
    private var parkedCallback: (@convention(c) (UInt64, Int8) -> Void)?
    private var parkedData: UInt64 = 0
    private var wakeScheduled = false

    /// - Parameters:
    ///   - readyAfterPolls: number of polls that report `MaybeReady` before the
    ///     future is ready. `Int.max` never becomes ready.
    ///   - wakeOnceWhenParked: deliver one native wake (`MaybeReady`) from a
    ///     background thread after the first poll parks its continuation.
    init(readyAfterPolls: Int, wakeOnceWhenParked: Bool) {
        self.readyAfterPolls = readyAfterPolls
        self.wakeOnceWhenParked = wakeOnceWhenParked
    }

    static func make(readyAfterPolls: Int, wakeOnceWhenParked: Bool) -> MockNativeFuture {
        let future = MockNativeFuture(
            readyAfterPolls: readyAfterPolls,
            wakeOnceWhenParked: wakeOnceWhenParked
        )
        future.token = registry.register(future)
        return future
    }

    var handle: RustFutureHandle? { UnsafeRawPointer(bitPattern: token) }

    // MARK: - Observations

    var observedFreeCount: Int { withLock { freeCount } }
    var observedPollCount: Int { withLock { pollCount } }
    var observedCancelCount: Int { withLock { cancelCount } }
    var observedCompleteCount: Int { withLock { completeCount } }
    var observedDisplacements: Int { withLock { displacements } }
    var observedViolations: [String] { withLock { violations } }

    /// One line of evidence for the CI log.
    var report: String {
        let detail = withLock { violations }
        let verdict = detail.isEmpty ? "clean" : "VIOLATION(\(detail.joined(separator: "; ")))"
        return verdict
    }

    /// Counters as they stood when the test asserted, for the log.
    var summary: String {
        withLock {
            "polls=\(pollCount) cancels=\(cancelCount) completes=\(completeCount) "
                + "frees=\(freeCount) displacements=\(displacements) violations=\(violations.count)"
        }
    }

    // MARK: - The "native" side

    func poll(
        _ handle: RustFutureHandle?,
        _ data: UInt64,
        _ callback: (@convention(c) (UInt64, Int8) -> Void)?
    ) -> Int8 {
        lock.lock()
        nativeDepth += 1
        lock.unlock()
        defer {
            lock.lock()
            nativeDepth -= 1
            lock.unlock()
        }

        lock.lock()
        if freed {
            violations.append("poll after free")
            lock.unlock()
            return Signal.ready.rawValue
        }
        pollCount += 1
        let attempt = pollCount
        let isReady = attempt > readyAfterPolls
        lock.unlock()

        if isReady {
            // Ready is delivered from inside the poll frame, exactly as
            // `RustFuture::poll` does.
            deliver(callback, data, .ready)
            return Signal.ready.rawValue
        }

        // Park, mirroring `store_continuation`.
        lock.lock()
        let displaced = parkedCallback
        if displaced != nil { displacements += 1 }
        parkedCallback = callback
        parkedData = data
        let wake = wakeOnceWhenParked && !wakeScheduled
        if wake { wakeScheduled = true }
        lock.unlock()

        if let displaced {
            // The runtime signals the displaced continuation Ready *before* it
            // stores the new one - the window in which the old code could free the
            // future that is about to be written to.
            deliver(displaced, data, .ready)
        }
        if wake {
            // A real wake arrives from a native thread, not from this call.
            DispatchQueue.global().async { [self] in
                deliverParkedWake()
            }
        }
        return Signal.maybeReady.rawValue
    }

    func cancel(_ handle: RustFutureHandle?) {
        lock.lock()
        nativeDepth += 1
        lock.unlock()
        defer {
            lock.lock()
            nativeDepth -= 1
            lock.unlock()
        }

        lock.lock()
        if freed {
            violations.append("cancel after free")
            lock.unlock()
            return
        }
        cancelCount += 1
        let parked = parkedCallback
        let parkedData = self.parkedData
        parkedCallback = nil
        lock.unlock()
        // A cancelled future delivers Ready to the continuation parked at that
        // moment (`ContinuationSignalPolicy::cancelled`).
        deliver(parked, parkedData, .ready)
    }

    func free(_ handle: RustFutureHandle?) {
        lock.lock()
        if nativeDepth > 0 { violations.append("free inside a native call") }
        if callbackDepth > 0 { violations.append("free inside a native callback") }
        if freed {
            violations.append("double free")
            lock.unlock()
            return
        }
        freed = true
        freeCount += 1
        parkedCallback = nil
        lock.unlock()
    }

    func complete(_ handle: RustFutureHandle?, _ status: UnsafeMutablePointer<FfiStatus>?) throws -> UInt32 {
        lock.lock()
        nativeDepth += 1
        lock.unlock()
        defer {
            lock.lock()
            nativeDepth -= 1
            lock.unlock()
        }

        lock.lock()
        if freed {
            violations.append("complete after free")
            lock.unlock()
            return MockNativeFuture.expectedValue
        }
        completeCount += 1
        lock.unlock()
        status?.pointee.code = 0
        return MockNativeFuture.expectedValue
    }

    // MARK: - Driving the generated runtime

    /// Runs the generated `boltffiAsyncCall` against this model, exactly as a
    /// generated call site would - same parameter types, same wiring.
    func call() async throws -> UInt32 {
        let futureHandle = handle
        return try await boltffiAsyncCall(
            futureHandle: futureHandle,
            poll: { [self] handle, data, callback in self.poll(handle, data, callback) },
            cancel: { [self] handle in self.cancel(handle) },
            free: { [self] handle in self.free(handle) },
            complete: { [self] handle, status in try self.complete(handle, status) }
        )
    }

    // MARK: - Waiting

    /// Waits until at least `count` polls have been observed, or the timeout
    /// expires. Bounded: a probe must never hang the suite.
    func waitUntilPolled(atLeast count: Int, timeout: TimeInterval = 10) async {
        let deadline = Date().addingTimeInterval(timeout)
        while observedPollCount < count, Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    /// Waits for the deferred free and then dwells briefly, so a violation that
    /// happens *after* the call returned (a stray re-poll, a late free) is still
    /// observed before the test asserts.
    func settle(timeout: TimeInterval = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while observedFreeCount < 1, Date() < deadline {
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    // MARK: - Internals

    private func deliverParkedWake() {
        lock.lock()
        let callback = parkedCallback
        let data = parkedData
        lock.unlock()
        deliver(callback, data, .maybeReady)
    }

    private func deliver(
        _ callback: (@convention(c) (UInt64, Int8) -> Void)?,
        _ data: UInt64,
        _ signal: Signal
    ) {
        guard let callback else { return }
        lock.lock()
        callbackDepth += 1
        lock.unlock()
        callback(data, signal.rawValue)
        lock.lock()
        callbackDepth -= 1
        lock.unlock()
    }

    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

/// The generated Swift async runtime's ownership proof.
///
/// Every test drives the *generated* `boltffiAsyncCall` against the model above
/// and asserts the invariant the candidate claims: the raw future handle has one
/// owner, `free` runs exactly once, it never runs while a native call or a
/// native-delivered callback can still dereference the handle, and a re-poll that
/// was queued before a cancellation cannot outlive the free. Each test prints a
/// `BOLT_LIFETIME` line so the CI log carries the result even when the assertion
/// that follows fails.
@Suite("Bolt async lifetime") struct BoltAsyncLifetime {
    @Test func completionInsideThePollFrameNeverFreesTheFuture() async throws {
        // The future is ready on the first poll, so the runtime delivers Ready
        // from inside `poll` - the frame the old runtime freed from.
        let native = MockNativeFuture.make(readyAfterPolls: 0, wakeOnceWhenParked: false)
        let value = try await native.call()
        await native.settle()
        #expect(value == MockNativeFuture.expectedValue)
        print("BOLT_LIFETIME completionInsidePollFrame=\(native.report) free-once=\(native.observedFreeCount == 1) \(native.summary)")
        #expect(native.observedFreeCount == 1)
        #expect(native.observedViolations.isEmpty)
    }

    @Test func cancellationRacingAWakeNeverPollsAFreedHandle() async throws {
        // Never ready; one native wake is delivered once the continuation parks, so
        // the runtime asks for a re-poll exactly while the caller is about to
        // cancel - the window that reproduced the SIGSEGV on the simulator.
        let native = MockNativeFuture.make(readyAfterPolls: Int.max, wakeOnceWhenParked: true)
        let task = Task { try await native.call() }
        await native.waitUntilPolled(atLeast: 1)
        task.cancel()
        let result = await task.result
        await native.settle()
        if case .success = result {
            // The mock never reports Ready, so a success would mean the runtime
            // completed a future that never finished.
            print("BOLT_LIFETIME cancellationRacingAWake=VIOLATION(completed a future that never became ready)")
        }
        print("BOLT_LIFETIME cancellationRacingAWake=\(native.report) \(native.summary)")
        #expect(native.observedViolations.isEmpty)
        #expect(native.observedFreeCount == 1)
        #expect(native.observedCancelCount >= 1)
    }

    @Test func repeatedAndPreCancelledCallsFreeExactlyOnce() async throws {
        // (a) repeated cancellation of the same in-flight call.
        let repeated = MockNativeFuture.make(readyAfterPolls: Int.max, wakeOnceWhenParked: false)
        let task = Task { try await repeated.call() }
        await repeated.waitUntilPolled(atLeast: 1)
        task.cancel()
        task.cancel()
        task.cancel()
        _ = await task.result
        await repeated.settle()
        print("BOLT_LIFETIME repeatedCancellation=\(repeated.report) \(repeated.summary)")
        #expect(repeated.observedViolations.isEmpty)
        #expect(repeated.observedFreeCount == 1)

        // (b) cancelled before the call could start: the cancellation handler runs
        // first and the operation body still has to reach the native future - and
        // still has to free it exactly once.
        let preCancelled = MockNativeFuture.make(readyAfterPolls: Int.max, wakeOnceWhenParked: false)
        let early = Task { try await preCancelled.call() }
        early.cancel()
        _ = await early.result
        await preCancelled.settle()
        print("BOLT_LIFETIME preCancelled=\(preCancelled.report) \(preCancelled.summary)")
        #expect(preCancelled.observedViolations.isEmpty)
        #expect(preCancelled.observedFreeCount == 1)
    }
}
