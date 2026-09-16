package dev.greenfield5.boltproof

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith

import dev.greenfield5.bolt.AsyncProbe
import dev.greenfield5.bolt.EventProbe
// The generator emits stream accessors as extension functions on the receiver
// (`fun EventProbe.eventsBatch(): EventsBatchSubscription`), and Kotlin requires
// an explicit import for a top-level extension - unlike the class itself, which
// comes in with the receiver's import. Without this the instrumentation APK does
// not compile (run 35102072270: unresolved reference 'eventsBatch').
import dev.greenfield5.bolt.eventsBatch
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.Continuation
import kotlin.coroutines.CoroutineContext
import kotlin.coroutines.EmptyCoroutineContext
import kotlin.coroutines.startCoroutine

// Runs in its own instrumentation invocation after the contract test, so a
// crash here cannot destroy the contract evidence. A crash is evidence, not
// permission to retry into a pass, and passing cannot by itself disprove #664.
//
// Exercises the lifecycle the task requires:
//   OPEN -> CLOSING -> CLOSED, new calls rejected once closing begins,
//   in-flight synchronous and asynchronous work draining safely, active
//   subscriptions accounted for, idempotent close, exactly one native free.
@RunWith(AndroidJUnit4::class)
class ConcurrentCloseTest {

    private fun awaitActive(probe: AsyncProbe, expected: UInt) {
        val deadline = System.nanoTime() + 3_000_000_000L
        while (probe.active() != expected) {
            check(System.nanoTime() < deadline) { "in-flight count never reached $expected" }
            Thread.sleep(1)
        }
    }

    @Test fun testConcurrentClose() {
        val rejected = AtomicInteger()
        val unexpected = AtomicReference<Throwable?>()
        val iterations = 500

        // 1. synchronous native call racing close()
        repeat(iterations) {
            val probe = AsyncProbe()
            val start = CountDownLatch(1)
            val worker = Thread {
                start.await()
                try { probe.hold(1u) }
                catch (expected: IllegalStateException) { rejected.incrementAndGet() }
            }
            worker.setUncaughtExceptionHandler { _, error -> unexpected.set(error) }
            worker.start()
            start.countDown()
            probe.close()
            worker.join(1000)
            check(unexpected.get() == null) { "unexpected worker exception: ${unexpected.get()}" }
            check(!worker.isAlive) { "native call did not drain" }
        }

        // 2. asynchronous call in flight racing close(); close is idempotent.
        //
        // The call is a *bounded* wait so that it can still complete after close().
        // A call that could only be woken by `release()` cannot: the contract rejects
        // every call on a closed object, so the wake would never be delivered and the
        // call would stay parked forever - which is what run 35118131437 measured in
        // both the patched and the unpatched tree ("async call did not drain" at
        // ConcurrentCloseTest.kt:120), i.e. the assertion was unevaluable rather than
        // failed. That is a real property of the contract and it is recorded in the
        // ownership audit: closing an object while one of its own futures is parked
        // leaves that future parked (and its retain keeps the object alive), because
        // close() defers the free but does not cancel or complete in-flight futures.
        // The post-close `release()` below is kept as the rejection assertion.
        repeat(200) {
            val probe = AsyncProbe()
            val failed = AtomicReference<Throwable?>()
            val settled = CountDownLatch(1)
            val worker = Thread {
                // The generated API is `suspend`, and the KVM-free phase of this
                // test must not need a coroutine library on the instrumentation
                // classpath: stdlib startCoroutine runs the block on this thread
                // until it suspends, then resumes it on whichever thread the
                // native completion arrives on - the same shape as a real caller.
                val call: suspend () -> UInt = { probe.waitValueBounded(3u, false, 150u) }
                call.startCoroutine(object : Continuation<UInt> {
                    override val context: CoroutineContext = EmptyCoroutineContext
                    override fun resumeWith(result: Result<UInt>) {
                        val error = result.exceptionOrNull()
                        when {
                            error is IllegalStateException -> rejected.incrementAndGet()
                            error != null -> failed.set(error)
                        }
                        settled.countDown()
                    }
                })
                check(settled.await(5, TimeUnit.SECONDS)) { "async call never settled" }
            }
            worker.setUncaughtExceptionHandler { _, error -> failed.set(error) }
            worker.start()
            awaitActive(probe, 1u)
            probe.close()
            probe.close()
            probe.close()
            // `release()` is an ordinary generated method, and after close() every
            // entry point is *required* to be rejected - that is the contract patch
            // 0002 (upstream #732) implements in the generated Kotlin retain guard.
            // Treating the rejection as a crash is what failed this suite in run
            // 35111780326: the guard threw before any native call, which is the safe
            // outcome, not a defect.
            //
            // Precisely, both builds reject an already-closed object with the same
            // message: the unpatched template's `boltffiHandle()` is
            // `check(!closed.get()); return handle`, so an *already closed* object
            // throws there too. The defect is the window between that check and the
            // native call - `close()` frees the handle in that window and the call
            // then runs on a freed handle. The patched build replaces the check with
            // `boltffiRetain()`/`boltffiRelease()`, an atomic in-flight counter that
            // defers the free until the racing call has drained, so this line is a
            // deterministic rejection rather than a race with the free.
            try {
                probe.release()
            } catch (expected: IllegalStateException) {
                rejected.incrementAndGet()
            }
            worker.join(3000)
            check(failed.get() == null) { "unexpected async exception: ${failed.get()}" }
            check(!worker.isAlive) { "async call did not drain" }
        }

        // 3. call after close is rejected, deterministically
        repeat(100) {
            val probe = AsyncProbe()
            probe.release()
            probe.close()
            try {
                probe.hold(1u)
                error("admitted a call after close")
            } catch (expected: IllegalStateException) {
                rejected.incrementAndGet()
            }
        }

        // 4. active event subscription while the owner is closed
        repeat(100) {
            val probe = EventProbe()
            val seen = AtomicInteger()
            val worker = Thread {
                try {
                    val stream = probe.eventsBatch()
                    while (seen.get() < 4) {
                        val batch = stream.popBatch(4)
                        if (batch.isEmpty()) Thread.sleep(1) else seen.addAndGet(batch.size)
                    }
                    stream.unsubscribe()
                } catch (expected: IllegalStateException) {
                    rejected.incrementAndGet()
                } catch (error: Throwable) {
                    unexpected.set(error)
                }
            }
            worker.setUncaughtExceptionHandler { _, error -> unexpected.set(error) }
            worker.start()
            probe.produce(4u)
            probe.close()
            worker.join(3000)
            check(unexpected.get() == null) { "unexpected stream exception: ${unexpected.get()}" }
            check(!worker.isAlive) { "stream did not drain" }
        }

        check(unexpected.get() == null) { "unexpected exception: ${unexpected.get()}" }
        // Every category ran; a zero here would mean a phase silently did nothing.
        check(rejected.get() >= 100) { "call-after-close was not exercised: ${rejected.get()}" }
        println(
            "BOLT_CLOSE iterations=$iterations async=200 after_close=100 stream=100 " +
                "rejected=${rejected.get()} completed=true; " +
                "passing is bounded evidence, not a proof against UB"
        )
    }
}
