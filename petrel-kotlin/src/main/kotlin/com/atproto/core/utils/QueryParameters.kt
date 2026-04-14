package com.atproto.core

import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.serializer

/**
 * Extension function to convert any serializable object to an ordered list
 * of query-parameter pairs.
 *
 * Uses kotlinx.serialization to serialize the object to JSON, then extracts
 * the key-value pairs. Array-valued properties are flattened into repeated
 * pairs — this mirrors the ATProto wire format
 * (e.g. `?actors=did:plc:aaa&actors=did:plc:bbb`) and matches the Swift
 * `Parametrizable.asQueryItems()` behaviour.
 *
 * Scalar null values are omitted. Nested objects are skipped.
 */
inline fun <reified T : Any> T.toQueryItems(): List<Pair<String, String>> {
    return try {
        val json = Json { encodeDefaults = false }
        val jsonElement = json.encodeToJsonElement(serializer<T>(), this)

        if (jsonElement is JsonObject) {
            buildList {
                for ((key, value) in jsonElement.entries) {
                    when (value) {
                        is JsonPrimitive -> {
                            primitiveToString(value)?.let { add(key to it) }
                        }
                        is JsonArray -> {
                            for (element in value) {
                                if (element is JsonPrimitive) {
                                    primitiveToString(element)?.let { add(key to it) }
                                }
                                // Skip nested objects/arrays inside arrays —
                                // ATProto query params are always primitive lists.
                            }
                        }
                        // Skip JsonObject — nested objects can't be expressed
                        // as query params.
                        else -> {}
                    }
                }
            }
        } else {
            emptyList()
        }
    } catch (_: SerializationException) {
        emptyList()
    }
}

/**
 * Legacy Map-based accessor kept for backwards compatibility with any
 * hand-written code that still calls `toQueryParams()`. Prefer
 * [toQueryItems], which preserves repeated keys for array-valued
 * parameters. This wrapper collapses duplicates (last-write-wins) and is
 * therefore lossy for array GET parameters — do not use it in new code.
 */
@Deprecated(
    message = "Use toQueryItems() to preserve repeated keys for array params.",
    replaceWith = ReplaceWith("toQueryItems().toMap()"),
)
inline fun <reified T : Any> T.toQueryParams(): Map<String, String> =
    toQueryItems().toMap()

@PublishedApi
internal fun primitiveToString(primitive: JsonPrimitive): String? {
    if (primitive is JsonNull) return null
    // Strings: unwrap the surrounding quotes that JsonPrimitive.toString()
    // adds. Skip empty-string values (matches the pre-existing behaviour
    // of the old Map-based toQueryParams()).
    return if (primitive.isString) {
        primitive.content.takeIf { it.isNotEmpty() }
    } else {
        primitive.content
    }
}
