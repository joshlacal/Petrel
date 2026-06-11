// Lexicon: 1, ID: com.atproto.server.requestPasswordReset
// Initiate a user account password reset via email.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerRequestPasswordResetDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.requestPasswordReset"
}

@Serializable
    data class ComAtprotoServerRequestPasswordResetInput(
        @SerialName("email")
        val email: String    )

/**
 * Initiate a user account password reset via email.
 *
 * Endpoint: com.atproto.server.requestPasswordReset
 */
suspend fun ATProtoClient.Com.Atproto.Server.requestPasswordReset(
input: ComAtprotoServerRequestPasswordResetInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.requestPasswordReset"

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
