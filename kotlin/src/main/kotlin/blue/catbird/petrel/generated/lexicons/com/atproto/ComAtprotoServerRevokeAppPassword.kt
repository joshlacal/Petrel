// Lexicon: 1, ID: com.atproto.server.revokeAppPassword
// Revoke an App Password by name.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerRevokeAppPasswordDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.revokeAppPassword"
}

@Serializable
    data class ComAtprotoServerRevokeAppPasswordInput(
        @SerialName("name")
        val name: String    )

/**
 * Revoke an App Password by name.
 *
 * Endpoint: com.atproto.server.revokeAppPassword
 */
suspend fun ATProtoClient.Com.Atproto.Server.revokeAppPassword(
input: ComAtprotoServerRevokeAppPasswordInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.server.revokeAppPassword"

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
