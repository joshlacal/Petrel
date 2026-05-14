// Lexicon: 1, ID: chat.bsky.group.approveJoinRequest
// [NOTE: This is under active development and should be considered unstable while this note is here]. Approves a request to join a group (via join link) the user owns. Action taken by the group owner.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupApproveJoinRequestDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.approveJoinRequest"
}

@Serializable
    data class ChatBskyGroupApproveJoinRequestInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("member")
        val member: DID    )

    @Serializable
    data class ChatBskyGroupApproveJoinRequestOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyGroupApproveJoinRequestError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyGroupApproveJoinRequestError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupApproveJoinRequestError("InsufficientRole", "")
        object MemberLimitReached: ChatBskyGroupApproveJoinRequestError("MemberLimitReached", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Approves a request to join a group (via join link) the user owns. Action taken by the group owner.
 *
 * Endpoint: chat.bsky.group.approveJoinRequest
 */
suspend fun ATProtoClient.Chat.Bsky.Group.approveJoinRequest(
input: ChatBskyGroupApproveJoinRequestInput): ATProtoResponse<ChatBskyGroupApproveJoinRequestOutput> {
    val endpoint = "chat.bsky.group.approveJoinRequest"

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
