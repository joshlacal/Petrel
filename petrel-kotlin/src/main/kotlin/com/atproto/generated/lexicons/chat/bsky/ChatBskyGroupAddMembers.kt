// Lexicon: 1, ID: chat.bsky.group.addMembers
// [NOTE: This is under active development and should be considered unstable while this note is here]. Adds members to a group. The members are added in 'request' status, so they have to accept it. This creates convo memberships.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
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
        object GroupInvitesDisabled: ChatBskyGroupAddMembersError("GroupInvitesDisabled", "")
        object ConvoLocked: ChatBskyGroupAddMembersError("ConvoLocked", "")
        object InsufficientRole: ChatBskyGroupAddMembersError("InsufficientRole", "")
        object InvalidConvo: ChatBskyGroupAddMembersError("InvalidConvo", "")
        object MemberLimitReached: ChatBskyGroupAddMembersError("MemberLimitReached", "")
        object NotFollowedBySender: ChatBskyGroupAddMembersError("NotFollowedBySender", "")
        object RecipientNotFound: ChatBskyGroupAddMembersError("RecipientNotFound", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Adds members to a group. The members are added in 'request' status, so they have to accept it. This creates convo memberships.
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
