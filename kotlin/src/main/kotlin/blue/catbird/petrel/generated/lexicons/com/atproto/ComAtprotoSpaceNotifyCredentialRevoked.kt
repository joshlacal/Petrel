// Lexicon: 1, ID: com.atproto.space.notifyCredentialRevoked
// Notify a repo host that the space authority has revoked one or more credentials. Authenticated with service auth from the space authority, addressed to the repo DID.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceNotifyCredentialRevokedDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.notifyCredentialRevoked"
}

@Serializable
    data class ComAtprotoSpaceNotifyCredentialRevokedInput(
// Reference to the space.        @SerialName("space")
        val space: SpaceRef,// The jti of the revoked credentials.        @SerialName("credentials")
        val credentials: List<String>    )

/**
 * Notify a repo host that the space authority has revoked one or more credentials. Authenticated with service auth from the space authority, addressed to the repo DID.
 *
 * Endpoint: com.atproto.space.notifyCredentialRevoked
 */
suspend fun ATProtoClient.Com.Atproto.Space.notifyCredentialRevoked(
input: ComAtprotoSpaceNotifyCredentialRevokedInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.space.notifyCredentialRevoked"

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
