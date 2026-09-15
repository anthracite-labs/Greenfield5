package dev.greenfield5.boltproof

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith

import dev.greenfield5.bolt.AsyncProbe
import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

// Run in a separate instrumentation process after contract tests. A crash is
// evidence, not permission to retry into a pass. Passing cannot disprove #664.
@RunWith(AndroidJUnit4::class)
class ConcurrentCloseTest {
    @Test fun testConcurrentClose() {
        val rejected = AtomicInteger()
        val unexpected = AtomicReference<Throwable?>()
        repeat(500) {
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
        println("BOLT_CLOSE iterations=500 exceptions=${rejected.get()} completed=true; NOT A PROOF AGAINST UB")
    }
}
