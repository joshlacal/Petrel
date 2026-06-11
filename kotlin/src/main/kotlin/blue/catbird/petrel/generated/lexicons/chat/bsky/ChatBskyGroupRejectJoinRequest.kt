// Lexicon: 1, ID: chat.bsky.group.rejectJoinRequest
// [NOTE: This is under active development and should be considered unstable while this note is here]. Rejects a request to join a group (via join link) the user owns. Action taken by the group owner.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupRejectJoinRequestDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.rejectJoinRequest"
}

@Serializable
    data class ChatBskyGroupRejectJoinRequestInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("member")
        val member: DID    )

    @Serializable
    class ChatBskyGroupRejectJoinRequestOutput

sealed class ChatBskyGroupRejectJoinRequestError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyGroupRejectJoinRequestError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupRejectJoinRequestError("InsufficientRole", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Rejects a request to join a group (via join link) the user owns. Action taken by the group owner.
 *
 * Endpoint: chat.bsky.group.rejectJoinRequest
 */
suspend fun ATProtoClient.Chat.Bsky.Group.rejectJoinRequest(
input: ChatBskyGroupRejectJoinRequestInput): ATProtoResponse<ChatBskyGroupRejectJoinRequestOutput> {
    val endpoint = "chat.bsky.group.rejectJoinRequest"

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
            "Accept" to "application/json"
        ),
        body = body
    )
}
