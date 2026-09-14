// Greenfield5 Android shell. Stack pins are justified in
// docs/decisions/0006-application-stack.md (ADR-0006).
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "greenfield5-android"
include(":app")
