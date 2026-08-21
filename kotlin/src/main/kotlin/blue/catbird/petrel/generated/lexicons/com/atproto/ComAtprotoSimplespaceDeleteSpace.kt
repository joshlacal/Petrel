// Lexicon: 1, ID: com.atproto.simplespace.deleteSpace
// Delete a space. The authenticated user must be the space owner. The authority's own repo in the space is deleted along with it, since the space host and the repo host are the same service here; other members' repos are flagged as belonging to a deleted space rather than erased. After deletion, all reads and writes against the space fail with SpaceNotFound, and getSpaceCredential answers SpaceDeleted so a syncer that missed the notification still learns to drop its copy. Idempotent. Requires auth, implemented by PDS.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoSimplespaceDeleteSpaceDefs {
    const val TYPE_IDENTIFIER = "com.atproto.simplespace.deleteSpace"
}

@Serializable
    data class ComAtprotoSimplespaceDeleteSpaceInput(
// Reference to the space to delete.        @SerialName("space")
        val space: SpaceRef    )

sealed class ComAtprotoSimplespaceDeleteSpaceError(val name: String, val description: String?) {
        object SpaceNotFound: ComAtprotoSimplespaceDeleteSpaceError("SpaceNotFound", "")
        object NotSpaceOwner: ComAtprotoSimplespaceDeleteSpaceError("NotSpaceOwner", "")
    }

/**
 * Delete a space. The authenticated user must be the space owner. The authority's own repo in the space is deleted along with it, since the space host and the repo host are the same service here; other members' repos are flagged as belonging to a deleted space rather than erased. After deletion, all reads and writes against the space fail with SpaceNotFound, and getSpaceCredential answers SpaceDeleted so a syncer that missed the notification still learns to drop its copy. Idempotent. Requires auth, implemented by PDS.
 *
 * Endpoint: com.atproto.simplespace.deleteSpace
 */
suspend fun ATProtoClient.Com.Atproto.Simplespace.deleteSpace(
input: ComAtprotoSimplespaceDeleteSpaceInput): ATProtoResponse<Unit> {
    val endpoint = "com.atproto.simplespace.deleteSpace"

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
