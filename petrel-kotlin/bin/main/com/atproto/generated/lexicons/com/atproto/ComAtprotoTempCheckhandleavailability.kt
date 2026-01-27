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

@Serializable
sealed interface ComAtprotoTempCheckHandleAvailabilityOutputResultUnion {
    @Serializable
    @SerialName("com.atproto.temp.checkHandleAvailability#ComAtprotoTempCheckHandleAvailabilityResultAvailable")
    data class ComAtprotoTempCheckHandleAvailabilityResultAvailable(val value: ComAtprotoTempCheckHandleAvailabilityResultAvailable) : ComAtprotoTempCheckHandleAvailabilityOutputResultUnion

    @Serializable
    @SerialName("com.atproto.temp.checkHandleAvailability#ComAtprotoTempCheckHandleAvailabilityResultUnavailable")
    data class ComAtprotoTempCheckHandleAvailabilityResultUnavailable(val value: ComAtprotoTempCheckHandleAvailabilityResultUnavailable) : ComAtprotoTempCheckHandleAvailabilityOutputResultUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ComAtprotoTempCheckHandleAvailabilityOutputResultUnion
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

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
