// Lexicon: 1, ID: com.atproto.identity.submitPlcOperation
// Validates a PLC operation to ensure that it doesn't violate a service's constraints or get the identity into a bad state, then submits it to the PLC registry
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
