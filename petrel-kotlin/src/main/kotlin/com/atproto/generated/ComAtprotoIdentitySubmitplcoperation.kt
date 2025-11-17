// Lexicon: 1, ID: com.atproto.identity.submitPlcOperation
// Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoIdentitySubmitplcoperation {
    const val TYPE_IDENTIFIER = "com.atproto.identity.submitPlcOperation"

    @Serializable
    data class Input(
        @SerialName("operation")
        val operation: JsonElement    )

}

/**
 * Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry
 *
 * Endpoint: com.atproto.identity.submitPlcOperation
 */
suspend fun ATProtoClient.Com.Atproto.Identity.submitplcoperation(
input: ComAtprotoIdentitySubmitplcoperation.Input): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.identity.submitPlcOperation"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
