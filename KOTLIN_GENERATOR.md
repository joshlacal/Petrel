# Kotlin Code Generator for Petrel

This document describes the Kotlin code generator that was added to the Petrel project, enabling automatic generation of Kotlin code from AT Protocol Lexicon files.

## Overview

The Kotlin generator creates idiomatic Kotlin code from the same Lexicon JSON files used for Swift generation. It produces:
- **239 Kotlin source files** with full AT Protocol API coverage
- **Data classes** with kotlinx.serialization support
- **Sealed interfaces** for union types
- **Suspend functions** for async API calls
- **Type-safe API client** with namespace hierarchy

## Architecture

### Generator Components

The generator follows a modular architecture with language-agnostic base classes:

```
Generator/
├── base_code_generator.py          # Abstract base for all generators
├── kotlin_code_generator.py        # Main Kotlin code generator
├── kotlin_type_converter.py        # Lexicon → Kotlin type mapping
├── kotlin_enum_generator.py        # Sealed interfaces & enum classes
├── kotlin_templates.py             # Template management
└── templates/kotlin/               # Jinja2 templates
    ├── mainTemplate.jinja
    ├── properties.jinja
    ├── sealedInterface.jinja
    ├── enumClass.jinja
    ├── query.jinja
    ├── procedure.jinja
    └── ... (13 templates total)
```

### Type Mappings

| Lexicon Type | Kotlin Type |
|--------------|-------------|
| `string` | `String` |
| `integer` | `Int` |
| `number` | `Double` |
| `boolean` | `Boolean` |
| `array` | `List<T>` |
| `union` | `sealed interface` |
| `string` (datetime) | `ATProtocolDate` |
| `string` (uri) | `URI` |
| `string` (at-uri) | `ATProtocolURI` |
| `string` (did) | `DID` |
| `string` (handle) | `Handle` |
| `string` (cid) | `CID` |
| `blob` | `Blob` |
| `bytes` | `ByteArray` |
| `unknown` | `JsonElement` |

## Usage

### Running the Generator

```bash
# Generate Kotlin code only
python run.py Generator/lexicons path/to/output --language kotlin

# Generate both Swift and Kotlin
python run.py Generator/lexicons path/to/output --language both

# Default (Swift only, for backward compatibility)
python run.py Generator/lexicons path/to/output
```

### Generated Code Examples

#### Data Class (from `app.bsky.actor.defs`)
```kotlin
@Serializable
data class ProfileViewBasic(
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

#### Sealed Interface (Union Type)
```kotlin
@Serializable
sealed interface FeedViewPostUnion {
    @Serializable
    @SerialName("app.bsky.feed.defs#postView")
    data class PostView(val value: AppBskyFeedDefs.PostView) : FeedViewPostUnion

    @Serializable
    @SerialName("app.bsky.feed.defs#reasonRepost")
    data class ReasonRepost(val value: AppBskyFeedDefs.ReasonRepost) : FeedViewPostUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : FeedViewPostUnion
}
```

#### API Method (Query)
```kotlin
/**
 * Get detailed profile view of an actor.
 *
 * Endpoint: app.bsky.actor.getProfile
 */
suspend fun ATProtoClient.App.Bsky.Actor.getProfile(
    parameters: AppBskyActorGetprofile.Parameters
): ATProtoResponse<AppBskyActorGetprofile.Output> {
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

## Project Structure

```
petrel-kotlin/
├── build.gradle.kts                         # Gradle build configuration
├── settings.gradle.kts                      # Gradle settings
├── gradle.properties                        # Gradle properties
└── src/main/kotlin/com/atproto/
    ├── core/
    │   └── ATProtoTypes.kt                  # Core types (DID, URI, Handle, etc.)
    ├── network/
    │   └── NetworkService.kt                # HTTP client & networking
    ├── client/
    │   └── ATProtoClient.kt                 # Main client class
    └── generated/                           # Generated code (239 files)
        ├── ATProtoClient.kt                 # Namespace hierarchy
        ├── AppBskyActorDefs.kt
        ├── AppBskyActorGetprofile.kt
        └── ... (236 more files)
```

## Key Features

### 1. No Circular Reference Boxing Required
Unlike Swift, Kotlin doesn't need `IndirectBox<T>` for value types:

```kotlin
// Swift needs boxing:
// private let _parent: IndirectBox<Post>

// Kotlin just works:
val parent: Post?
```

### 2. Superior Union Type Support
Kotlin's sealed interfaces are more natural than Swift enums:

```kotlin
sealed interface PostUnion {
    data class View(val value: PostView) : PostUnion
    data class Unexpected(val value: JsonElement) : PostUnion
}

// Pattern matching:
when (post) {
    is PostUnion.View -> handleView(post.value)
    is PostUnion.Unexpected -> handleUnknown()
}
```

### 3. Coroutines Instead of Actors
```kotlin
// Swift: actor ATProtoClient
// Kotlin: class ATProtoClient with suspend functions

suspend fun getProfile(...): ATProtoResponse<Output> {
    // Coroutine-based async
}
```

### 4. kotlinx.serialization Integration
```kotlin
@Serializable
data class Profile(
    @SerialName("displayName")
    val displayName: String?,
    // Automatic JSON serialization
)
```

## Core Types Implemented

All essential AT Protocol types have been translated to Kotlin:

- ✅ **ATProtocolDate** - ISO 8601 datetime with Instant backing
- ✅ **URI** - General URI with DID support
- ✅ **ATProtocolURI** - AT Protocol-specific URIs (at://)
- ✅ **DID** - Decentralized Identifiers
- ✅ **Handle** - AT Protocol handles with validation
- ✅ **ATIdentifier** - Sealed class for DID or Handle
- ✅ **CID** - Content Identifiers
- ✅ **NSID** - Namespaced Identifiers
- ✅ **Blob** - Binary large objects
- ✅ **Bytes** - Base64-encoded byte arrays
- ✅ **Language** - Language codes

## Network Layer

The Kotlin network layer uses **Ktor Client**:

```kotlin
class NetworkService(
    private val baseUrl: String = "https://bsky.social"
) {
    suspend inline fun <reified T> performRequest(
        method: String,
        endpoint: String,
        queryParams: Map<String, String>? = null,
        headers: Map<String, String> = emptyMap(),
        body: Any? = null
    ): ATProtoResponse<T>
}
```

### Dependencies
- **Kotlin 1.9.22**
- **kotlinx.coroutines** for async/await
- **kotlinx.serialization** for JSON
- **Ktor Client** for HTTP networking

## Differences from Swift

| Feature | Swift | Kotlin |
|---------|-------|--------|
| Async | async/await + actors | suspend functions + coroutines |
| Optionals | `Type?` | `Type?` (same!) |
| Serialization | Codable protocol | kotlinx.serialization |
| Union types | enum with associated values | sealed interface |
| Circular refs | IndirectBox required | Native support |
| Namespaces | nested classes | nested classes/objects |
| Nullability | Optional<T> | Type? |

## Generated Statistics

- **Total files generated**: 239
- **Lexicons processed**: 238
- **Sealed interfaces**: ~150+
- **Data classes**: ~500+
- **API endpoints**: ~200+
- **Lines of code**: ~50,000+

## Future Enhancements

Potential improvements for the Kotlin generator:

1. **Authentication Service** - OAuth and token management
2. **WebSocket Support** - For subscription endpoints (Flow-based)
3. **CBOR Encoding** - For DAG-CBOR support
4. **DID Resolution** - Full DID document handling
5. **Rich Text Utilities** - Facets and mentions
6. **Multiplatform** - Kotlin/Native for iOS, Kotlin/JS for web
7. **Testing** - Unit tests for generated code
8. **Documentation** - KDoc generation from lexicon descriptions

## Building the Project

```bash
cd petrel-kotlin

# Build
./gradlew build

# Run tests
./gradlew test

# Publish to local Maven
./gradlew publishToMavenLocal
```

## Integration Example

```kotlin
import com.atproto.client.ATProtoClient
import com.atproto.core.*

suspend fun main() {
    val client = ATProtoClient("https://bsky.social")

    try {
        val params = AppBskyActorGetprofile.Parameters(
            actor = ATIdentifier.parse("bsky.app")
        )

        val response = client.app.bsky.actor.getProfile(params)

        if (response.responseCode == 200) {
            println("Profile: ${response.data}")
        }
    } finally {
        client.close()
    }
}
```

## Comparison with Swift Generator

Both generators share:
- ✅ Same lexicon input files
- ✅ Same two-pass architecture (cycle detection)
- ✅ Template-based code generation
- ✅ Type-safe API methods
- ✅ Forward-compatible union handling

Kotlin-specific advantages:
- ✅ Simpler recursive type handling
- ✅ More expressive sealed interfaces
- ✅ Multiplatform potential (JVM, Native, JS, Wasm)
- ✅ Null-safety built into type system
- ✅ Coroutines for structured concurrency

## Contributing

To extend the Kotlin generator:

1. **Add new types**: Edit `kotlin_type_converter.py`
2. **Modify templates**: Update files in `Generator/templates/kotlin/`
3. **Change generation logic**: Modify `kotlin_code_generator.py`
4. **Add new features**: Extend base classes in `base_code_generator.py`

## License

Same license as the Petrel project.

---

**Generated**: November 17, 2025
**Generator Version**: 1.0.0
**Lexicon Version**: 1
**Total Lexicons**: 238
