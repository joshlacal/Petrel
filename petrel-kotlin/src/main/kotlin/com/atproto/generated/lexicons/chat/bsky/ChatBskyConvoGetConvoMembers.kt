// Lexicon: 1, ID: chat.bsky.convo.getConvoMembers
// Returns a paginated list of members from a conversation.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetConvoMembersDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getConvoMembers"
}

@Serializable
    data class ChatBskyConvoGetConvoMembersParameters(
        @SerialName("convoId")
        val convoId: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ChatBskyConvoGetConvoMembersOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("members")
        val members: List<ChatBskyActorDefsProfileViewBasic>    )

sealed class ChatBskyConvoGetConvoMembersError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoGetConvoMembersError("InvalidConvo", "")
    }

/**
 * Returns a paginated list of members from a conversation.
 *
 * Endpoint: chat.bsky.convo.getConvoMembers
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getConvoMembers(
parameters: ChatBskyConvoGetConvoMembersParameters): ATProtoResponse<ChatBskyConvoGetConvoMembersOutput> {
    val endpoint = "chat.bsky.convo.getConvoMembers"

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
