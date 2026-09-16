package dev.greenfield5.boltproof

import dev.greenfield5.bolt.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

// Called from instrumentation: every operation below goes through the generated
// BoltFFI Kotlin bindings into real JNI into the real Rust library. Nothing
// here re-implements product behaviour in Kotlin.
object Contract {
    fun run() = runBlocking {
        check(coreVersion() == "0.1.0")
        GreenfieldSession(Role.SENDER, ConnectionMode.INTERNET).use { sender ->
            check(sender.stateCode() == 0.toUByte())
            check(sender.apply(SessionCommand.START_PAIRING) == SessionState.AWAITING_PEER)
            check(sender.sendCommand(2u) == 2.toUByte())
            try { sender.sendCommand(2u); error("admitted second viewer") }
            catch (e: BridgeError.ViewerAlreadyConnected) { }
            check(sender.sendCommand(3u) == 3.toUByte())
            check(sender.viewerApproved())
            try { sender.sendCommand(255u); error("accepted invalid command") }
            catch (e: BridgeError.UnknownCommandCode) { check(e.code == 255.toUByte()) }
            check(sender.stateCode() == 3.toUByte())
        }
        GreenfieldSession(Role.VIEWER, ConnectionMode.LOCAL).use { viewer ->
            check(viewer.sendCommand(1u) == 2.toUByte())
            check(viewer.sendCommand(4u) == 3.toUByte())
        }
        try { GreenfieldSession.fromCodes(255u, 0u); error("accepted invalid role") }
        catch (e: BridgeError.UnknownRoleCode) { check(e.code == 255.toUByte()) }
        try { GreenfieldSession.fromCodes(0u, 255u); error("accepted invalid mode") }
        catch (e: BridgeError.UnknownModeCode) { check(e.code == 255.toUByte()) }
        val padded = PaddingProbe(0x1234u, 0x55667788u)
        check(paddingRoundTrip(padded) == padded)
        check(paddingList(padded) == listOf(padded, padded))
        val input = LayoutProbe(7u, 0x1122334455667788uL, 0x3344u, "layout")
        check(roundTrip(input) == input)

        // async success / typed async failure / cleanup after the future settles
        AsyncProbe().use { probe ->
            probe.release()
            check(probe.waitValue(42u, false) == 42u)
            try { probe.waitValue(42u, true); error("missing typed error") }
            catch (e: BridgeError.SessionEnded) { }
            check(probe.active() == 0u)
        }

        // cancellation before completion; cleanup after cancellation
        AsyncProbe().use { probe ->
            val task = launch(Dispatchers.Default) { probe.waitValue(1u, false) }
            withTimeout(3000) { while (probe.active() == 0u) yield() }
            task.cancelAndJoin()
            check(probe.active() == 0u)
        }

        // repeated cancellation: cancel twice, and once after the future settled.
        // The generated runtime must free the native future exactly once.
        var repeatedCancellations = 0
        repeat(100) {
            AsyncProbe().use { probe ->
                val task = launch(Dispatchers.Default) { runCatching { probe.waitValue(1u, false) } }
                withTimeout(3000) { while (probe.active() == 0u) yield() }
                task.cancel()
                task.cancel()
                withTimeout(3000) { task.join() }
                check(probe.active() == 0u)
                repeatedCancellations++
            }
        }

        // cancellation racing readiness: release() makes the future ready while
        // the cancel lands. One of the two paths must claim the completion.
        var racedCancellations = 0
        repeat(100) {
            AsyncProbe().use { probe ->
                val task = launch(Dispatchers.Default) { runCatching { probe.waitValue(5u, false) } }
                withTimeout(3000) { while (probe.active() == 0u) yield() }
                probe.release()
                task.cancel()
                withTimeout(3000) { task.join() }
                check(probe.active() == 0u)
                racedCancellations++
            }
        }

        // bounded batch path: native ring capacity is 8, producer overshoots it
        EventProbe().use { probe ->
            probe.eventsBatch().use { stream ->
                check(probe.produce(100u) == 8u)
                val batch = stream.popBatch(100)
                check(batch == (0u..7u).toList())
                check(probe.dropped() == 92u)
                probe.stop()
                stream.unsubscribe()
            }
        }

        // normal asynchronous consumer: every accepted event arrives, in order
        EventProbe().use { probe ->
            val seen = mutableListOf<UInt>()
            val consumer = launch { probe.events().take(8).collect { seen.add(it) } }
            yield()
            check(probe.produce(8u) == 8u)
            withTimeout(3000) { consumer.join() }
            check(seen == (0u..7u).toList())
            check(probe.dropped() == 0u)
            check(!probe.isActive())
        }

        // slow consumer: produce one at a time so the native ring never fills,
        // consume slowly. Records the resulting host backlog explicitly.
        EventProbe().use { probe ->
            val seen = mutableListOf<UInt>()
            val consumer = launch { probe.events().collect { seen.add(it); delay(10) } }
            yield()
            repeat(200) { probe.produce(1u); delay(1) }
            consumer.cancelAndJoin()
            check(seen.zipWithNext().all { (a, b) -> a < b })
            check(probe.produced() == 200u)
            check(!probe.isActive())
            println(
                "BOLT_STREAM produced=${probe.produced()} consumed=${seen.size} " +
                    "nativeDropped=${probe.dropped()} unconsumed=${200 - seen.size - probe.dropped().toInt()}"
            )
        }

        // shutdown: drain, stop the producer, then confirm the subscription is gone
        EventProbe().use { probe ->
            probe.eventsBatch().use { stream ->
                probe.produce(3u)
                check(stream.popBatch(8).size == 3)
                check(stream.popBatch(8).isEmpty())
                probe.stop()
                check(!probe.isActive())
                stream.unsubscribe()
            }
        }

        println(
            "BOLT_PROOF version=0.1.0 sender=PASS viewer=PASS typed_errors=PASS layout=PASS " +
                "async=PASS cancellation=PASS repeated_cancel=$repeatedCancellations " +
                "raced_cancel=$racedCancellations batch=8/100 dropped=92"
        )
    }
}
