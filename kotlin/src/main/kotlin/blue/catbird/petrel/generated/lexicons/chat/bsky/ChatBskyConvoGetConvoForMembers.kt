// Lexicon: 1, ID: chat.bsky.convo.getConvoForMembers
// Get or create a 1-1 conversation for the given members. Always returns the same direct (non-group) conversation. To create a group conversation, use createGroup.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetConvoForMembersDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getConvoForMembers"
}

@Serializable
    data class ChatBskyConvoGetConvoForMembersParameters(
        @SerialName("members")
        val members: List<DID>    )

    @Serializable
    data class ChatBskyConvoGetConvoForMembersOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyConvoGetConvoForMembersError(val name: String, val description: String?) {
        object AccountSuspended: ChatBskyConvoGetConvoForMembersError("AccountSuspended", "")
        object BlockedActor: ChatBskyConvoGetConvoForMembersError("BlockedActor", "")
        object BlockedSubject: ChatBskyConvoGetConvoForMembersError("BlockedSubject", "")
        object MessagesDisabled: ChatBskyConvoGetConvoForMembersError("MessagesDisabled", "")
        object NotFollowedBySender: ChatBskyConvoGetConvoForMembersError("NotFollowedBySender", "")
        object RecipientNotFound: ChatBskyConvoGetConvoForMembersError("RecipientNotFound", "")
    }

/**
 * Get or create a 1-1 conversation for the given members. Always returns the same direct (non-group) conversation. To create a group conversation, use createGroup.
 *
 * Endpoint: chat.bsky.convo.getConvoForMembers
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getConvoForMembers(
parameters: ChatBskyConvoGetConvoForMembersParameters): ATProtoResponse<ChatBskyConvoGetConvoForMembersOutput> {
    val endpoint = "chat.bsky.convo.getConvoForMembers"

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
