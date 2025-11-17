// Lexicon: 1, ID: com.atproto.temp.checkHandleAvailability
// Checks whether the provided handle is available. If the handle is not available, available suggestions will be returned. Optional inputs will be used to generate suggestions.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface OutputResultUnion {
    @Serializable
    @SerialName("com.atproto.temp.checkHandleAvailability#Resultavailable")
    data class Resultavailable(val value: Resultavailable) : OutputResultUnion

    @Serializable
    @SerialName("com.atproto.temp.checkHandleAvailability#Resultunavailable")
    data class Resultunavailable(val value: Resultunavailable) : OutputResultUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputResultUnion
}

object ComAtprotoTempCheckhandleavailability {
    const val TYPE_IDENTIFIER = "com.atproto.temp.checkHandleAvailability"

    @Serializable
    data class Parameters(
// Tentative handle. Will be checked for availability or used to build handle suggestions.        @SerialName("handle")
        val handle: Handle,// User-provided email. Might be used to build handle suggestions.        @SerialName("email")
        val email: String? = null,// User-provided birth date. Might be used to build handle suggestions.        @SerialName("birthDate")
        val birthDate: ATProtocolDate? = null    )

        @Serializable
    data class Output(
// Echo of the input handle.        @SerialName("handle")
        val handle: Handle,        @SerialName("result")
        val result: OutputResultUnion    )

    sealed class Error(val name: String, val description: String?) {
        object Invalidemail: Error("InvalidEmail", "An invalid email was provided.")
    }

        /**
     * Indicates the provided handle is available.
     */
    @Serializable
    data class Resultavailable(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#resultavailable"
        }
    }

    /**
     * Indicates the provided handle is unavailable and gives suggestions of available handles.
     */
    @Serializable
    data class Resultunavailable(
/** List of suggested handles based on the provided inputs. */        @SerialName("suggestions")
        val suggestions: List<Suggestion>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#resultunavailable"
        }
    }

    @Serializable
    data class Suggestion(
        @SerialName("handle")
        val handle: Handle,/** Method used to build this suggestion. Should be considered opaque to clients. Can be used for metrics. */        @SerialName("method")
        val method: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#suggestion"
        }
    }

}

/**
 * Checks whether the provided handle is available. If the handle is not available, available suggestions will be returned. Optional inputs will be used to generate suggestions.
 *
 * Endpoint: com.atproto.temp.checkHandleAvailability
 */
suspend fun ATProtoClient.Com.Atproto.Temp.checkhandleavailability(
parameters: ComAtprotoTempCheckhandleavailability.Parameters): ATProtoResponse<ComAtprotoTempCheckhandleavailability.Output> {
    val endpoint = "com.atproto.temp.checkHandleAvailability"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
