// Lexicon: 1, ID: com.atproto.server.requestEmailConfirmation
// Request an email with a code to confirm ownership of email.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerRequestEmailConfirmationDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.requestEmailConfirmation"
}

/**
 * Request an email with a code to confirm ownership of email.
 *
 * Endpoint: com.atproto.server.requestEmailConfirmation
 */
suspend fun ATProtoClient.Com.Atproto.Server.requestEmailConfirmation(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.requestEmailConfirmation"

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
