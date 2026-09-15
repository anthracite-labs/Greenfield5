package dev.greenfield5.boltproof

@Suppress("DEPRECATION")
class NativeContractTest : android.test.AndroidTestCase() {
    fun testRealRustContract() { Contract.run() }
}
