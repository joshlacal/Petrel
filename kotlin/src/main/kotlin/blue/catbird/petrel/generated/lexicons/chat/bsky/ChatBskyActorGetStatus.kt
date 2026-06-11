// Lexicon: 1, ID: chat.bsky.actor.getStatus
// Get the authenticated viewer's chat status: whether their account is chat-disabled and whether their group-membership additions are restricted to accounts they follow.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyActorGetStatusDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.getStatus"
}

    @Serializable
    data class ChatBskyActorGetStatusOutput(
// True when the viewer's account is disabled and cannot actively participate in chat.        @SerialName("chatDisabled")
        val chatDisabled: Boolean,// Whether the viewer's account is allowed to create group chats. New accounts are restricted from creating groups.        @SerialName("canCreateGroups")
        val canCreateGroups: Boolean,// The maximum number of members allowed in a group conversation.        @SerialName("groupMemberLimit")
        val groupMemberLimit: Int    )

/**
 * Get the authenticated viewer's chat status: whether their account is chat-disabled and whether their group-membership additions are restricted to accounts they follow.
 *
 * Endpoint: chat.bsky.actor.getStatus
 */
suspend fun ATProtoClient.Chat.Bsky.Actor.getStatus(
): ATProtoResponse<ChatBskyActorGetStatusOutput> {
    val endpoint = "chat.bsky.actor.getStatus"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
