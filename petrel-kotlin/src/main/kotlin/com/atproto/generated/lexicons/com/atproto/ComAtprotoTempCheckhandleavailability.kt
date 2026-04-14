// Lexicon: 1, ID: com.atproto.temp.checkHandleAvailability
// Checks whether the provided handle is available. If the handle is not available, available suggestions will be returned. Optional inputs will be used to generate suggestions.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoTempCheckHandleAvailabilityDefs {
    const val TYPE_IDENTIFIER = "com.atproto.temp.checkHandleAvailability"
}

@Serializable(with = ComAtprotoTempCheckHandleAvailabilityOutputResultUnionSerializer::class)
sealed interface ComAtprotoTempCheckHandleAvailabilityOutputResultUnion {
    @Serializable
    data class ResultAvailable(val value: com.atproto.generated.ComAtprotoTempCheckHandleAvailabilityResultAvailable) : ComAtprotoTempCheckHandleAvailabilityOutputResultUnion

    @Serializable
    data class ResultUnavailable(val value: com.atproto.generated.ComAtprotoTempCheckHandleAvailabilityResultUnavailable) : ComAtprotoTempCheckHandleAvailabilityOutputResultUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ComAtprotoTempCheckHandleAvailabilityOutputResultUnion
}

object ComAtprotoTempCheckHandleAvailabilityOutputResultUnionSerializer : kotlinx.serialization.KSerializer<ComAtprotoTempCheckHandleAvailabilityOutputResultUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ComAtprotoTempCheckHandleAvailabilityOutputResultUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ComAtprotoTempCheckHandleAvailabilityOutputResultUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ComAtprotoTempCheckHandleAvailabilityOutputResultUnion.ResultAvailable -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoTempCheckHandleAvailabilityResultAvailable.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.temp.checkHandleAvailability#resultAvailable")
                })
            }
            is ComAtprotoTempCheckHandleAvailabilityOutputResultUnion.ResultUnavailable -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoTempCheckHandleAvailabilityResultUnavailable.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.temp.checkHandleAvailability#resultUnavailable")
                })
            }
            is ComAtprotoTempCheckHandleAvailabilityOutputResultUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ComAtprotoTempCheckHandleAvailabilityOutputResultUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.temp.checkHandleAvailability#resultAvailable" -> ComAtprotoTempCheckHandleAvailabilityOutputResultUnion.ResultAvailable(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoTempCheckHandleAvailabilityResultAvailable.serializer(), element)
            )
            "com.atproto.temp.checkHandleAvailability#resultUnavailable" -> ComAtprotoTempCheckHandleAvailabilityOutputResultUnion.ResultUnavailable(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoTempCheckHandleAvailabilityResultUnavailable.serializer(), element)
            )
            else -> ComAtprotoTempCheckHandleAvailabilityOutputResultUnion.Unexpected(element)
        }
    }
}

    /**
     * Indicates the provided handle is available.
     */
    @Serializable
    class ComAtprotoTempCheckHandleAvailabilityResultAvailable {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoTempCheckHandleAvailabilityResultAvailable"
        }
    }

    /**
     * Indicates the provided handle is unavailable and gives suggestions of available handles.
     */
    @Serializable
    data class ComAtprotoTempCheckHandleAvailabilityResultUnavailable(
/** List of suggested handles based on the provided inputs. */        @SerialName("suggestions")
        val suggestions: List<ComAtprotoTempCheckHandleAvailabilitySuggestion>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoTempCheckHandleAvailabilityResultUnavailable"
        }
    }

    @Serializable
    data class ComAtprotoTempCheckHandleAvailabilitySuggestion(
        @SerialName("handle")
        val handle: Handle,/** Method used to build this suggestion. Should be considered opaque to clients. Can be used for metrics. */        @SerialName("method")
        val method: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoTempCheckHandleAvailabilitySuggestion"
        }
    }

@Serializable
    data class ComAtprotoTempCheckHandleAvailabilityParameters(
// Tentative handle. Will be checked for availability or used to build handle suggestions.        @SerialName("handle")
        val handle: Handle,// User-provided email. Might be used to build handle suggestions.        @SerialName("email")
        val email: String? = null,// User-provided birth date. Might be used to build handle suggestions.        @SerialName("birthDate")
        val birthDate: ATProtocolDate? = null    )

    @Serializable
    data class ComAtprotoTempCheckHandleAvailabilityOutput(
// Echo of the input handle.        @SerialName("handle")
        val handle: Handle,        @SerialName("result")
        val result: ComAtprotoTempCheckHandleAvailabilityOutputResultUnion    )

sealed class ComAtprotoTempCheckHandleAvailabilityError(val name: String, val description: String?) {
        object InvalidEmail: ComAtprotoTempCheckHandleAvailabilityError("InvalidEmail", "An invalid email was provided.")
    }

/**
 * Checks whether the provided handle is available. If the handle is not available, available suggestions will be returned. Optional inputs will be used to generate suggestions.
 *
 * Endpoint: com.atproto.temp.checkHandleAvailability
 */
suspend fun ATProtoClient.Com.Atproto.Temp.checkHandleAvailability(
parameters: ComAtprotoTempCheckHandleAvailabilityParameters): ATProtoResponse<ComAtprotoTempCheckHandleAvailabilityOutput> {
    val endpoint = "com.atproto.temp.checkHandleAvailability"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
