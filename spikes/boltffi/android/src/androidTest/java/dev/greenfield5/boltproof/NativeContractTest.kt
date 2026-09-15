package dev.greenfield5.boltproof

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NativeContractTest {
    @Test fun testRealRustContract() { Contract.run() }
}
