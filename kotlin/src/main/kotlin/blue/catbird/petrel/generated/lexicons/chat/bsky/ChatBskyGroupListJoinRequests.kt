// Lexicon: 1, ID: chat.bsky.group.listJoinRequests
// Lists a page of request to join a group (via join link) the user owns. Shows the data from the owner's point of view.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupListJoinRequestsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.listJoinRequests"
}

@Serializable
    data class ChatBskyGroupListJoinRequestsParameters(
        @SerialName("convoId")
        val convoId: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ChatBskyGroupListJoinRequestsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("requests")
        val requests: List<ChatBskyGroupDefsJoinRequestView>    )

sealed class ChatBskyGroupListJoinRequestsError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyGroupListJoinRequestsError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupListJoinRequestsError("InsufficientRole", "")
    }

/**
 * Lists a page of request to join a group (via join link) the user owns. Shows the data from the owner's point of view.
 *
 * Endpoint: chat.bsky.group.listJoinRequests
 */
suspend fun ATProtoClient.Chat.Bsky.Group.listJoinRequests(
parameters: ChatBskyGroupListJoinRequestsParameters): ATProtoResponse<ChatBskyGroupListJoinRequestsOutput> {
    val endpoint = "chat.bsky.group.listJoinRequests"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
