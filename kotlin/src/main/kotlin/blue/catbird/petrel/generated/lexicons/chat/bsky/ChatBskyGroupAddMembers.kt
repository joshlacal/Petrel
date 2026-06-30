// Lexicon: 1, ID: chat.bsky.group.addMembers
// Adds members to a group. The members are added in 'request' status, so they have to accept it. This creates convo memberships.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupAddMembersDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.addMembers"
}

@Serializable
    data class ChatBskyGroupAddMembersInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("members")
        val members: List<DID>    )

    @Serializable
    data class ChatBskyGroupAddMembersOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView,        @SerialName("addedMembers")
        val addedMembers: List<ChatBskyActorDefsProfileViewBasic>? = null    )

sealed class ChatBskyGroupAddMembersError(val name: String, val description: String?) {
        object AccountSuspended: ChatBskyGroupAddMembersError("AccountSuspended", "")
        object BlockedActor: ChatBskyGroupAddMembersError("BlockedActor", "")
        object BlockedSubject: ChatBskyGroupAddMembersError("BlockedSubject", "")
        object ConvoLocked: ChatBskyGroupAddMembersError("ConvoLocked", "")
        object InsufficientRole: ChatBskyGroupAddMembersError("InsufficientRole", "")
        object InvalidConvo: ChatBskyGroupAddMembersError("InvalidConvo", "")
        object MemberLimitReached: ChatBskyGroupAddMembersError("MemberLimitReached", "")
        object NotFollowedBySender: ChatBskyGroupAddMembersError("NotFollowedBySender", "")
        object RecipientNotFound: ChatBskyGroupAddMembersError("RecipientNotFound", "")
        object UserForbidsGroups: ChatBskyGroupAddMembersError("UserForbidsGroups", "")
    }

/**
 * Adds members to a group. The members are added in 'request' status, so they have to accept it. This creates convo memberships.
 *
 * Endpoint: chat.bsky.group.addMembers
 */
suspend fun ATProtoClient.Chat.Bsky.Group.addMembers(
input: ChatBskyGroupAddMembersInput): ATProtoResponse<ChatBskyGroupAddMembersOutput> {
    val endpoint = "chat.bsky.group.addMembers"

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
