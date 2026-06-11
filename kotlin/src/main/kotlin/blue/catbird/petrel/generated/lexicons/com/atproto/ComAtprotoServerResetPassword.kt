// Lexicon: 1, ID: com.atproto.server.resetPassword
// Reset a user account password using a token.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerResetPasswordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.resetPassword"
}

@Serializable
    data class ComAtprotoServerResetPasswordInput(
        @SerialName("token")
        val token: String,        @SerialName("password")
        val password: String    )

sealed class ComAtprotoServerResetPasswordError(val name: String, val description: String?) {
        object ExpiredToken: ComAtprotoServerResetPasswordError("ExpiredToken", "")
        object InvalidToken: ComAtprotoServerResetPasswordError("InvalidToken", "")
    }

/**
 * Reset a user account password using a token.
 *
 * Endpoint: com.atproto.server.resetPassword
 */
suspend fun ATProtoClient.Com.Atproto.Server.resetPassword(
input: ComAtprotoServerResetPasswordInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.resetPassword"

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
