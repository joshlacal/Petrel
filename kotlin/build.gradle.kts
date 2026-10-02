import kotlinx.benchmark.gradle.JvmBenchmarkTarget

plugins {
    kotlin("jvm")
    kotlin("plugin.serialization")
    kotlin("plugin.allopen") version "2.0.21"
    id("org.jetbrains.kotlin.plugin.compose")
    id("org.jetbrains.kotlinx.benchmark") version "0.4.13"
    `maven-publish`
}

group = "blue.catbird"
version = providers.gradleProperty("version").orNull?.takeIf { it != "unspecified" } ?: "0.1.0"

// JMH requires classes annotated with @State to be non-final
allOpen {
    annotation("org.openjdk.jmh.annotations.State")
}

// Dedicated source set for benchmarks to avoid leaking into published jars
sourceSets {
    create("benchmark")
}

tasks.withType<ProcessResources> {
    duplicatesStrategy = DuplicatesStrategy.INCLUDE
}

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

    // Benchmark runtime
    "benchmarkImplementation"("org.jetbrains.kotlinx:kotlinx-benchmark-runtime:0.4.13")
}

kotlin {
    jvmToolchain(17)
    // Allows benchmarks to access all internal models, functions, and serializers from main
    target.compilations.getByName("benchmark")
        .associateWith(target.compilations.getByName("main"))
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

benchmark {
    targets {
        register("benchmark") {
            this as JvmBenchmarkTarget
            jmhVersion = "1.37"
        }
    }
    configurations {
        named("main") {
            warmups = 2
            iterations = 3
            iterationTime = 1
            iterationTimeUnit = "s"
            reportFormat = "text"
        }
        register("smoke") {
            warmups = 1
            iterations = 1
            iterationTime = 500
            iterationTimeUnit = "ms"
            reportFormat = "text"
        }
    }
}

// Custom task to execute JMH with GC profiling to capture B/op
tasks.register<JavaExec>("benchmarkGc") {
    group = "benchmark"
    description = "Executes benchmarks with JMH GC profiler to measure heap allocations (B/op)"
    dependsOn("benchmarkBenchmarkJar")
    mainClass.set("org.openjdk.jmh.Main")
    classpath(fileTree(layout.buildDirectory.dir("benchmarks")) {
        include("**/*-JMH.jar")
    })
    val filter = providers.gradleProperty("benchmarkFilter").orNull ?: ".*"
    args("-prof", "gc", "-f", "1", "-wi", "2", "-i", "3", filter)
}
