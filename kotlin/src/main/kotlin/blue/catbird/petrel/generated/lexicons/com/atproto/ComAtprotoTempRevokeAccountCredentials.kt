// Lexicon: 1, ID: com.atproto.temp.revokeAccountCredentials
// Revoke sessions, password, and app passwords associated with account. May be resolved by a password reset.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoTempRevokeAccountCredentialsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.temp.revokeAccountCredentials"
}

@Serializable
    data class ComAtprotoTempRevokeAccountCredentialsInput(
        @SerialName("account")
        val account: ATIdentifier    )

/**
 * Revoke sessions, password, and app passwords associated with account. May be resolved by a password reset.
 *
 * Endpoint: com.atproto.temp.revokeAccountCredentials
 */
suspend fun ATProtoClient.Com.Atproto.Temp.revokeAccountCredentials(
input: ComAtprotoTempRevokeAccountCredentialsInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.temp.revokeAccountCredentials"

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
