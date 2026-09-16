import org.jetbrains.kotlin.gradle.dsl.JvmTarget
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}
android {
    namespace = "dev.greenfield5.boltproof"
    compileSdk = 37
    defaultConfig {
        applicationId = "dev.greenfield5.boltproof"
        minSdk = 29
        targetSdk = 37
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    // Proof-only switch (spike app, never the product tree): the same
    // instrumentation can be built against the minified release variant, so a
    // keep-rule mistake fails a real execution instead of a static grep.
    // Both variants are signed with the debug key because the instrumentation
    // APK must be signed with the same certificate as the app it drives.
    testBuildType = (findProperty("proofTestBuildType") as String?) ?: "debug"
    buildTypes {
        getByName("release") {
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // When `testBuildType = release`, the androidTest APK is minified as well.
            // Give it the same rules explicitly: the keep rules must cover the test APK,
            // and so must the annotation-only `-dontwarn` rules - otherwise the test
            // APK's R8 run fails assembly on androidx.test's absent annotations
            // (run 35119746524) even though nothing is wrong with the bridge.
            testProguardFiles("proguard-rules.pro")
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    sourceSets.getByName("main") {
        kotlin.srcDirs("../generated", "../host")
        jniLibs.srcDirs("../generated/jniLibs")
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlin { compilerOptions { jvmTarget = JvmTarget.fromTarget("17") } }
}
dependencies {
    implementation(platform(libs.androidx.compose.bom))
    implementation("androidx.compose.runtime:runtime")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
}
