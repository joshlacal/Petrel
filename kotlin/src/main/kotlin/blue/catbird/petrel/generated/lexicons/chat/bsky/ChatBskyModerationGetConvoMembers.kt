// Lexicon: 1, ID: chat.bsky.moderation.getConvoMembers
// Returns a paginated list of members from a conversation, for moderation purposes. Does not require the requester to be a member of the conversation.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyModerationGetConvoMembersDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.getConvoMembers"
}

@Serializable
    data class ChatBskyModerationGetConvoMembersParameters(
        @SerialName("convoId")
        val convoId: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ChatBskyModerationGetConvoMembersOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("members")
        val members: List<ChatBskyActorDefsProfileViewBasic>    )

sealed class ChatBskyModerationGetConvoMembersError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyModerationGetConvoMembersError("InvalidConvo", "")
    }

/**
 * Returns a paginated list of members from a conversation, for moderation purposes. Does not require the requester to be a member of the conversation.
 *
 * Endpoint: chat.bsky.moderation.getConvoMembers
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.getConvoMembers(
parameters: ChatBskyModerationGetConvoMembersParameters): ATProtoResponse<ChatBskyModerationGetConvoMembersOutput> {
    val endpoint = "chat.bsky.moderation.getConvoMembers"

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
