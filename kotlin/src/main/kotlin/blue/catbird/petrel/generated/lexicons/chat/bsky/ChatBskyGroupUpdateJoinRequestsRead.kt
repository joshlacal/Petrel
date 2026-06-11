// Lexicon: 1, ID: chat.bsky.group.updateJoinRequestsRead
// [NOTE: This is under active development and should be considered unstable while this note is here]. Marks all join requests as read for the group owner.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupUpdateJoinRequestsReadDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.updateJoinRequestsRead"
}

@Serializable
    data class ChatBskyGroupUpdateJoinRequestsReadInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    class ChatBskyGroupUpdateJoinRequestsReadOutput

sealed class ChatBskyGroupUpdateJoinRequestsReadError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyGroupUpdateJoinRequestsReadError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupUpdateJoinRequestsReadError("InsufficientRole", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Marks all join requests as read for the group owner.
 *
 * Endpoint: chat.bsky.group.updateJoinRequestsRead
 */
suspend fun ATProtoClient.Chat.Bsky.Group.updateJoinRequestsRead(
input: ChatBskyGroupUpdateJoinRequestsReadInput): ATProtoResponse<ChatBskyGroupUpdateJoinRequestsReadOutput> {
    val endpoint = "chat.bsky.group.updateJoinRequestsRead"

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
