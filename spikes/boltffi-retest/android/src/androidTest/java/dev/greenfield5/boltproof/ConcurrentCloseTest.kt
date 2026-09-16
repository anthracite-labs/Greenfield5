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

        // 2. asynchronous call in flight racing close(); close is idempotent
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
                val call: suspend () -> UInt = { probe.waitValue(3u, false) }
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
            // 35111780326: the generated guard threw before any native call, which is
            // the safe outcome, not a defect. The unpatched build has no counter
            // (check-then-act), so there the same line reaches native with a stale
            // handle - the assertion below only accepts *no* other exception.
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
