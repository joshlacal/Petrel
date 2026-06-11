plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
    id("org.jetbrains.kotlin.plugin.compose")
    `maven-publish`
}

group = "blue.catbird"
version = providers.gradleProperty("version").orNull?.takeIf { it != "unspecified" } ?: "0.1.0"

dependencies {
    // Kotlin standard library
    implementation(kotlin("stdlib"))

    // Compose runtime (required for Compose compiler stability metadata)
    implementation("androidx.compose.runtime:runtime:1.8.3")

    // Kotlin Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.9.0")

    // Kotlin Serialization for JSON and CBOR (DAG-CBOR WebSocket frames)
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-cbor:1.7.3")

    // Ktor client for HTTP networking
    implementation("io.ktor:ktor-client-core:3.0.2")
    implementation("io.ktor:ktor-client-cio:3.0.2") // CIO engine
    implementation("io.ktor:ktor-client-content-negotiation:3.0.2")
    implementation("io.ktor:ktor-serialization-kotlinx-json:3.0.2")
    implementation("io.ktor:ktor-client-logging:3.0.2")
    implementation("io.ktor:ktor-client-websockets:3.0.2")

    // Testing
    testImplementation(kotlin("test"))
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.9.0")
    testImplementation("io.ktor:ktor-client-mock:3.0.2")
}

kotlin {
    jvmToolchain(17)
}

java {
    withSourcesJar()
    withJavadocJar()
}

tasks.test {
    useJUnitPlatform()
}

publishing {
    publications {
        create<MavenPublication>("maven") {
            from(components["java"])

            pom {
                name.set("petrel-kotlin")
                description.set("Kotlin SDK for the AT Protocol and Bluesky, generated from the official lexicons")
                url.set("https://github.com/joshlacal/Petrel")
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }
                developers {
                    developer {
                        id.set("joshlacal")
                        name.set("Josh LaCalamito")
                    }
                }
                scm {
                    url.set("https://github.com/joshlacal/Petrel")
                    connection.set("scm:git:https://github.com/joshlacal/Petrel.git")
                    developerConnection.set("scm:git:ssh://git@github.com/joshlacal/Petrel.git")
                }
            }
        }
    }
}

// Signing is required by Maven Central but must not break local/CI builds:
// only active when a key is provided (ORG_GRADLE_PROJECT_signingKey /
// ORG_GRADLE_PROJECT_signingPassword environment variables).
if (providers.gradleProperty("signingKey").isPresent) {
    apply(plugin = "signing")
    configure<SigningExtension> {
        useInMemoryPgpKeys(
            providers.gradleProperty("signingKey").get(),
            providers.gradleProperty("signingPassword").orNull ?: ""
        )
        sign(extensions.getByType<PublishingExtension>().publications["maven"])
    }
}
