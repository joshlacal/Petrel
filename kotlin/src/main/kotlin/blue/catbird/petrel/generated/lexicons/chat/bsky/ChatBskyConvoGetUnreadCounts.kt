// Lexicon: 1, ID: chat.bsky.convo.getUnreadCounts
// Returns unread conversation counts for conversations that are unlocked, not muted, split by convo status. Direct convos are excluded when a block relationship exists between the actor and the other member, or when the other member's account is deleted or deactivated. Group convos are considered unread if they have unread join request counts.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetUnreadCountsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getUnreadCounts"
}

@Serializable
    data class ChatBskyConvoGetUnreadCountsParameters(
// When false, group convos are excluded from the counts.        @SerialName("includeGroupChats")
        val includeGroupChats: Boolean? = null    )

    @Serializable
    data class ChatBskyConvoGetUnreadCountsOutput(
// Number of unread, unlocked accepted convos. Counts convos with unread messages and unread join requests. Capped at 100, where 100 means more than 99.        @SerialName("unreadAcceptedConvos")
        val unreadAcceptedConvos: Int,// Number of unread, unlocked request convos. Includes convos with unread messages, but not with unread join request, since only the owner of a group has join requests to read, and the group would necessarily be accepted. Capped at 100, where 100 means more than 99.        @SerialName("unreadRequestConvos")
        val unreadRequestConvos: Int    )

/**
 * Returns unread conversation counts for conversations that are unlocked, not muted, split by convo status. Direct convos are excluded when a block relationship exists between the actor and the other member, or when the other member's account is deleted or deactivated. Group convos are considered unread if they have unread join request counts.
 *
 * Endpoint: chat.bsky.convo.getUnreadCounts
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getUnreadCounts(
parameters: ChatBskyConvoGetUnreadCountsParameters): ATProtoResponse<ChatBskyConvoGetUnreadCountsOutput> {
    val endpoint = "chat.bsky.convo.getUnreadCounts"

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
