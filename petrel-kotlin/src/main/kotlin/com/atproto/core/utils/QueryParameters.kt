package com.atproto.core

import kotlinx.serialization.SerializationException
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.serializer
import kotlin.reflect.KClass

/**
 * Extension function to convert any serializable object to query parameters.
 * Uses kotlinx.serialization to serialize the object to JSON, then extracts
 * the key-value pairs as query parameters.
 */
inline fun <reified T : Any> T.toQueryParams(): Map<String, String> {
    return try {
        val json = Json { encodeDefaults = false }
        val jsonElement = json.encodeToJsonElement(serializer<T>(), this)

        if (jsonElement is JsonObject) {
            jsonElement.entries.mapNotNull { (key, value) ->
                when (value) {
                    is JsonPrimitive -> {
                        // Only include non-null primitive values
                        if (!value.isString || value.content.isNotEmpty()) {
                            key to value.toString().removeSurrounding("\"")
                        } else {
                            null
                        }
                    }
                    else -> null // Skip arrays and objects in query params
                }
            }.toMap()
        } else {
            emptyMap()
        }
    } catch (e: SerializationException) {
        emptyMap()
    }
}
