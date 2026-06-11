// Lexicon: 1, ID: com.atproto.server.confirmEmail
// Confirm an email using a token from com.atproto.server.requestEmailConfirmation.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerConfirmEmailDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.confirmEmail"
}

@Serializable
    data class ComAtprotoServerConfirmEmailInput(
        @SerialName("email")
        val email: String,        @SerialName("token")
        val token: String    )

sealed class ComAtprotoServerConfirmEmailError(val name: String, val description: String?) {
        object AccountNotFound: ComAtprotoServerConfirmEmailError("AccountNotFound", "")
        object ExpiredToken: ComAtprotoServerConfirmEmailError("ExpiredToken", "")
        object InvalidToken: ComAtprotoServerConfirmEmailError("InvalidToken", "")
        object InvalidEmail: ComAtprotoServerConfirmEmailError("InvalidEmail", "")
    }

/**
 * Confirm an email using a token from com.atproto.server.requestEmailConfirmation.
 *
 * Endpoint: com.atproto.server.confirmEmail
 */
suspend fun ATProtoClient.Com.Atproto.Server.confirmEmail(
input: ComAtprotoServerConfirmEmailInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.confirmEmail"

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
