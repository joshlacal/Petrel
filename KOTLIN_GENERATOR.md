# Kotlin code generator

The Petrel generator includes a Kotlin code generation backend that emits strongly typed Kotlin models, sealed interfaces, and client endpoints from AT Protocol Lexicon definitions.

The `0.2.0` package release is scoped to the Swift Package Manager product. Kotlin generator output is repository-internal tooling, not a shipped product of this Swift package. Kotlin artifact publication and Kotlin/Swift feature parity are outside the `0.2.0` SPM release gate.

## Generator architecture

The code generator lives in `generator/` and provides language-specific generators sharing common base validation and cycle-detection logic:

```
generator/
├── main.py                         # CLI entrypoint and manifest runner
├── base_code_generator.py          # Abstract base generator class
├── kotlin_code_generator.py        # Kotlin code generator
├── kotlin_type_converter.py        # Lexicon to Kotlin type mapping
├── kotlin_enum_generator.py        # Sealed interfaces and enums
├── kotlin_templates.py             # Template manager for Kotlin
├── manifests/
│   └── petrel-core.json            # Manifest defining inputs and outputs
└── templates/kotlin/               # Jinja2 templates
    ├── mainTemplate.jinja
    ├── KotlinClientMain.jinja
    ├── properties.jinja
    ├── sealedInterface.jinja
    ├── enumClass.jinja
    ├── closedEnumClass.jinja
    ├── parameters.jinja
    ├── input.jinja
    ├── output.jinja
    ├── query.jinja
    ├── procedure.jinja
    ├── subscription.jinja
    ├── record.jinja
    ├── message.jinja
    ├── strictRefSerializer.jinja
    ├── lexiconDefinitions.jinja
    └── errorsEnum.jinja
```

## Type mappings

| Lexicon type | Kotlin type | Notes |
|---|---|---|
| `string` | `String` | Standard string |
| `integer` | `Int` | 32-bit signed integer |
| `number` | `Double` | Floating-point number |
| `boolean` | `Boolean` | Primitive boolean |
| `array` | `List<T>` | Immutable list |
| `union` | `sealed interface` | Discriminated union types |
| `string` (`datetime`) | `ATProtocolDate` | ISO 8601 timestamp |
| `string` (`uri`) | `URI` | General URI representation |
| `string` (`at-uri`) | `ATProtocolURI` | AT Protocol record URI (`at://`) |
| `string` (`did`) | `DID` | Decentralized identifier |
| `string` (`handle`) | `Handle` | AT Protocol handle |
| `string` (`cid`) | `CID` | Content identifier |
| `blob` | `Blob` | Binary large object metadata |
| `bytes` | `ByteArray` | Raw byte data |
| `unknown` | `JsonElement` | Unresolved JSON payload |

## Run the generator

The generator is driven by `generator/manifests/petrel-core.json`, which configures lexicon paths, namespace filters, and output locations for both Swift and Kotlin:

To generate Kotlin files:

```bash
python3 run.py --manifest generator/manifests/petrel-core.json --language kotlin
```

To generate both Swift and Kotlin files:

```bash
python3 run.py --manifest generator/manifests/petrel-core.json --language both
```

### Formatting behavior

Unlike the Swift generation workflow—which requires running `swiftformat Sources/Petrel/Generated` after generation—Kotlin generator output has **no post-format step**.

The generator emits deterministic, byte-identical Kotlin source directly from its Jinja templates and post-processing routines. Byte-level stability is verified by unit tests in `generator/tests/test_kotlin_strict_ref_byte_stability.py`. Do not add or run `ktlint` or `spotless` passes on generated Kotlin output.

## Project structure

Generated Kotlin code is written to `kotlin/src/main/kotlin/blue/catbird/petrel/generated`:

```
kotlin/
├── build.gradle.kts                         # Gradle build configuration
├── settings.gradle.kts                      # Gradle settings
├── gradle.properties                        # Gradle properties
└── src/main/kotlin/blue/catbird/petrel/
    ├── auth/                                # Authentication strategies
    ├── client/                              # Base client classes
    ├── core/                                # Core types (DID, URI, Handle, etc.)
    ├── network/                             # HTTP and WebSocket networking
    ├── runtime/                             # Runtime utilities
    └── generated/                           # Generator output
        ├── client/
        │   └── ATProtoClientGenerated.kt    # Generated namespace client extensions
        └── lexicons/                        # Generated lexicon models
            ├── app/bsky/
            ├── chat/bsky/
            ├── com/atproto/
            └── site/standard/
```

## Generated code structure

### Model data class

Generated from object definitions:

```kotlin
package blue.catbird.petrel.generated

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import blue.catbird.petrel.core.DID
import blue.catbird.petrel.core.Handle
import blue.catbird.petrel.core.URI

@Serializable
data class AppBskyActorDefsProfileViewBasic(
    @SerialName("did")
    val did: DID,
    @SerialName("handle")
    val handle: Handle,
    @SerialName("displayName")
    val displayName: String? = null,
    @SerialName("avatar")
    val avatar: URI? = null
) {
    companion object {
        const val TYPE_IDENTIFIER = "app.bsky.actor.defs#profileViewBasic"
    }
}
```

### Union sealed interface

Generated from lexicon union definitions:

```kotlin
package blue.catbird.petrel.generated

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonElement

@Serializable
sealed interface AppBskyFeedDefsFeedViewPostUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#postView")
    data class PostView(val value: AppBskyFeedDefsPostView) : AppBskyFeedDefsFeedViewPostUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#reasonRepost")
    data class ReasonRepost(val value: AppBskyFeedDefsReasonRepost) : AppBskyFeedDefsFeedViewPostUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsFeedViewPostUnion
}
```

### Client query extension

Generated from query definitions:

```kotlin
/**
 * Get detailed profile view of an actor.
 *
 * Endpoint: app.bsky.actor.getProfile
 */
suspend fun ATProtoClient.App.Bsky.Actor.getProfile(
    parameters: AppBskyActorGetProfile.Parameters
): ATProtoResponse<AppBskyActorGetProfile.Output> {
    val endpoint = "app.bsky.actor.getProfile"

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = parameters.toQueryParams(),
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
```

## Build the Kotlin project

To compile the Kotlin project and execute its test suite:

```bash
cd kotlin
./gradlew build
./gradlew test
```
