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
///  * the handle is the generated `RustFutureHandle` (`UnsafeRawPointer`), and
///    `poll`, `cancel` and `complete` only *borrow* it
///    (`Arc::from_raw` + `mem::forget` in `RustFutureHandleAccess`), while `free`
///    *consumes* it (`consume_future`) and is the only call that invalidates it;
///  * `RustFuture::poll` invokes the callback from inside its own frame whenever
///    the future is ready *or cancelled* (`is_cancelled || poll_future_once`, then
///    `continuation_callback(data, Ready)`), and `rust_future_cancel` delivers
///    `Ready` to the continuation parked at that moment - so the callback is not
///    always a wake on another thread;
///  * a second poll while a continuation is parked displaces the older one
///    (`RustFutureContinuationPolicy::displaced()` = `Ready`, delivered from inside
///    `store_continuation` *before* the new continuation is written);
///  * `wake()` delivers `MaybeReady` from whichever thread woke the future.
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
    private var cancelled = false
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

    /// `RustFutureHandle` is declared in the generated C module and aliased to
    /// `UnsafeRawPointer`; the app module does not re-export it, so the probe
    /// spells the underlying Swift type. It is the same type - the generated
    /// signature accepts it unchanged - and it keeps this test target free of a
    /// new module import it may not be able to resolve.
    var handle: UnsafeRawPointer? { UnsafeRawPointer(bitPattern: token) }

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
        _ handle: UnsafeRawPointer?,
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
        // `RustFuture::poll` short-circuits a cancelled future to Ready and
        // invokes the callback inside its own frame; a cancelled future must
        // therefore never park a new continuation.
        let wasCancelled = cancelled
        let isReady = wasCancelled || attempt > readyAfterPolls
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
        // Each parked continuation carries its own callback *and* its own data
        // (the generated driver hands the runtime a `passRetained(self)` pointer
        // per poll), so the displaced pair must be delivered together. Delivering
        // the new poll's data to the old callback would over-release the driver.
        let displacedData = parkedData
        if displaced != nil { displacements += 1 }
        parkedCallback = callback
        parkedData = data
        let wake = wakeOnceWhenParked && !wakeScheduled
        if wake { wakeScheduled = true }
        lock.unlock()

        if let displaced {
            // The runtime signals the displaced continuation with `Policy::displaced()`
            // = Ready *before* it stores the new one - the window in which the old
            // code could free the future that is about to be written to.
            deliver(displaced, displacedData, .ready)
        }
        if wake {
            // A real wake arrives from a native thread, not from this call.
            DispatchQueue.global().async { [self] in
                deliverParkedWake()
            }
        }
        return Signal.maybeReady.rawValue
    }

    func cancel(_ handle: UnsafeRawPointer?) {
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
        // Lifetime latch, not a counter: once cancelled, every later poll reports
        // Ready from inside its own frame (`wake_target.is_cancelled()`).
        cancelled = true
        let parked = parkedCallback
        let parkedData = self.parkedData
        parkedCallback = nil
        lock.unlock()
        // A cancelled future delivers Ready to the continuation parked at that
        // moment (`ContinuationSignalPolicy::cancelled`).
        deliver(parked, parkedData, .ready)
    }

    func free(_ handle: UnsafeRawPointer?) {
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

    /// Called by the completion closure at the call site below.
    ///
    /// The status pointer is deliberately not touched: `boltffiAsyncCall` starts
    /// from `var status = FfiStatus()` (all zeros = `FFI_STATUS_OK`) and reads
    /// `status.code` back, so leaving it untouched is the success path. That keeps
    /// `FfiStatus` - another C-module type - out of this file, and it keeps the
    /// probe about lifetime, not error mapping (the contract suite owns that).
    func complete(_ handle: UnsafeRawPointer?) -> UInt32 {
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
        return MockNativeFuture.expectedValue
    }

    // MARK: - Driving the generated runtime

    /// Runs the generated `boltffiAsyncCall` against this model, exactly as a
    /// generated call site would - same parameter types, same wiring.
    ///
    /// The completion closure is written inline and its second parameter is left
    /// unnamed, so its parameter types come from the generated signature instead
    /// of being spelled here: the app module does not re-export the C types that
    /// signature names, and a probe that named them would not compile.
    func call() async throws -> UInt32 {
        let futureHandle = handle
        return try await boltffiAsyncCall(
            futureHandle: futureHandle,
            poll: { [self] handle, data, callback in self.poll(handle, data, callback) },
            cancel: { [self] handle in self.cancel(handle) },
            free: { [self] handle in self.free(handle) },
            complete: { [self] handle, _ in self.complete(handle) }
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

    @Test func cancellationOfAParkedCallNeverFreesInsideTheNativeFrame() async throws {
        // Never ready, so the first poll parks a continuation; the caller then
        // cancels. The runtime answers `rust_future_cancel` by delivering Ready
        // to that parked continuation *from inside the cancel call*, which is the
        // frame the old runtime freed the future in - and the continuation it
        // resumed is the same one the cancellation handler has already claimed.
        let native = MockNativeFuture.make(readyAfterPolls: Int.max, wakeOnceWhenParked: false)
        let task = Task { try await native.call() }
        await native.waitUntilPolled(atLeast: 1)
        task.cancel()
        let result = await task.result
        await native.settle()
        if case .success = result {
            print("BOLT_LIFETIME cancelledCallReturnedAValue=observed")
        }
        print("BOLT_LIFETIME cancellationOfParkedCall=\(native.report) \(native.summary)")
        #expect(native.observedViolations.isEmpty)
        #expect(native.observedFreeCount == 1)
        #expect(native.observedCancelCount >= 1)
    }

    @Test func wakeDrivenRepollNeverOutlivesTheFree() async throws {
        // The re-poll path: a native wake arrives once the first poll parked a
        // continuation, so the runtime asks for another poll. Under the real
        // policy that second poll displaces the parked continuation with Ready
        // *from inside the poll frame*, so the old runtime completed and freed
        // the future while `RustFuture::poll` was still executing.
        //
        // The assertions below are lifetime-only. Whether the call completes early
        // because of the displacement policy is recorded, not asserted: it is
        // upstream behaviour (`RustFutureContinuationPolicy::displaced()`) and the
        // real-Rust acceptance suite exercises it against actual native state.
        let native = MockNativeFuture.make(readyAfterPolls: Int.max, wakeOnceWhenParked: true)
        let task = Task { try await native.call() }
        await native.waitUntilPolled(atLeast: 2)
        let outcome = await task.result
        if case .success = outcome {
            print("BOLT_LIFETIME displacement-completed-a-pending-future=observed(upstream policy)")
        }
        task.cancel()
        _ = await task.result
        await native.settle()
        print("BOLT_LIFETIME wakeDrivenRepoll=\(native.report) \(native.summary)")
        #expect(native.observedViolations.isEmpty)
        #expect(native.observedFreeCount == 1)
        #expect(native.observedPollCount >= 2)
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
