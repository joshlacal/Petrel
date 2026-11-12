pluginManagement {
    repositories {
        gradlePluginPortal()
        mavenCentral()
    }
    // Used only when this project builds on its own. The Catbird Android app
    // includes it as a subproject, and its own Kotlin plugin version applies.
    val kotlinVersion = "2.4.21"
    plugins {
        kotlin("jvm") version kotlinVersion
        kotlin("plugin.serialization") version kotlinVersion
        kotlin("plugin.allopen") version kotlinVersion
        id("org.jetbrains.kotlin.plugin.compose") version kotlinVersion
    }
}

dependencyResolutionManagement {
    repositories {
        mavenCentral()
        google()
    }
}

rootProject.name = "petrel-kotlin"
