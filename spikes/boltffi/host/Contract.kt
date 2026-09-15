package dev.greenfield5.boltproof

import dev.greenfield5.bolt.*
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*

// Called from instrumentation: all operations below use generated native APIs.
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
        val padded = PaddingProbe(0x1234u, 0x55667788u)
        check(paddingRoundTrip(padded) == padded)
        check(paddingList(padded) == listOf(padded, padded))
        val input = LayoutProbe(7u, 0x1122334455667788uL, 0x3344u, "layout")
        check(roundTrip(input) == input)
        AsyncProbe().use { probe ->
            probe.release()
            check(probe.waitValue(42u, false) == 42u)
            try { probe.waitValue(42u, true); error("missing typed error") }
            catch (e: BridgeError.SessionEnded) { }
            check(probe.active() == 0u)
        }
        AsyncProbe().use { probe ->
            val task = launch { probe.waitValue(1u, false) }
            withTimeout(3000) { while (probe.active() == 0u) yield() }
            task.cancelAndJoin()
            check(probe.active() == 0u)
        }
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
        EventProbe().use { probe ->
            val seen = mutableListOf<UInt>()
            val consumer = launch { probe.events().collect { seen.add(it); delay(10) } }
            yield()
            repeat(200) { probe.produce(1u); delay(1) }
            consumer.cancelAndJoin()
            check(seen.zipWithNext().all { (a, b) -> a < b })
            check(probe.produced() == 200u)
            check(!probe.isActive())
            println("BOLT_STREAM produced=${probe.produced()} consumed=${seen.size} nativeDropped=${probe.dropped()} unconsumed=${200 - seen.size - probe.dropped().toInt()}")
        }
        println("BOLT_PROOF version=0.1.0 sender=PASS viewer=PASS typed_errors=PASS layout=PASS async=PASS cancellation=PASS batch=8/100 dropped=92")
    }
}
