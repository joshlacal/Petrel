// Lexicon: 1, ID: com.atproto.identity.requestPlcOperationSignature
// Request an email with a code to in order to request a signed PLC operation. Requires Auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoIdentityRequestPlcOperationSignatureDefs {
    const val TYPE_IDENTIFIER = "com.atproto.identity.requestPlcOperationSignature"
}

/**
 * Request an email with a code to in order to request a signed PLC operation. Requires Auth.
 *
 * Endpoint: com.atproto.identity.requestPlcOperationSignature
 */
suspend fun ATProtoClient.Com.Atproto.Identity.requestPlcOperationSignature(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.identity.requestPlcOperationSignature"

    val body: String? = null
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
