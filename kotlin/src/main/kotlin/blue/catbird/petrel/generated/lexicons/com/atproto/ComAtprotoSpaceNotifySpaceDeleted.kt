// Lexicon: 1, ID: com.atproto.space.notifySpaceDeleted
// Notify a syncing service that a space has been deleted, and that it should drop every copy of the space's data it holds. Sent by the space authority to the services registered for the space, best-effort. Authenticated with service auth addressed to the receiving service.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSpaceNotifySpaceDeletedDefs {
    const val TYPE_IDENTIFIER = "com.atproto.space.notifySpaceDeleted"
}

@Serializable
    data class ComAtprotoSpaceNotifySpaceDeletedInput(
// Reference to the deleted space.        @SerialName("space")
        val space: SpaceRef    )

/**
 * Notify a syncing service that a space has been deleted, and that it should drop every copy of the space's data it holds. Sent by the space authority to the services registered for the space, best-effort. Authenticated with service auth addressed to the receiving service.
 *
 * Endpoint: com.atproto.space.notifySpaceDeleted
 */
suspend fun ATProtoClient.Com.Atproto.Space.notifySpaceDeleted(
input: ComAtprotoSpaceNotifySpaceDeletedInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.space.notifySpaceDeleted"

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
