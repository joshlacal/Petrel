// Lexicon: 1, ID: com.atproto.identity.submitPlcOperation
// Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoIdentitySubmitPlcOperationDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.submitPlcOperation"
}

@Serializable
    data class ComAtprotoIdentitySubmitPlcOperationInput(
        @SerialName("operation")
        val operation: JsonElement    )

/**
 * Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry
 *
 * Endpoint: com.atproto.identity.submitPlcOperation
 */
suspend fun ATProtoClient.Com.Atproto.Identity.submitPlcOperation(
input: ComAtprotoIdentitySubmitPlcOperationInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.identity.submitPlcOperation"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
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
