// Lexicon: 1, ID: com.atproto.server.deleteSession
// Delete the current session. Requires auth using the 'refreshJwt' (not the 'accessJwt').
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerDeleteSessionDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.deleteSession"
}

sealed class ComAtprotoServerDeleteSessionError(val name: String, val description: String?) {
        object InvalidToken: ComAtprotoServerDeleteSessionError("InvalidToken", "")
        object ExpiredToken: ComAtprotoServerDeleteSessionError("ExpiredToken", "")
    }

/**
 * Delete the current session. Requires auth using the 'refreshJwt' (not the 'accessJwt').
 *
 * Endpoint: com.atproto.server.deleteSession
 */
suspend fun ATProtoClient.Com.Atproto.Server.deleteSession(
): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.deleteSession"

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
