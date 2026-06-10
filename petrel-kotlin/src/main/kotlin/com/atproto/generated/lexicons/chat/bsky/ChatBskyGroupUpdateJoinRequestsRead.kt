// Lexicon: 1, ID: chat.bsky.group.updateJoinRequestsRead
// [NOTE: This is under active development and should be considered unstable while this note is here]. Marks all join requests as read for the group owner.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
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
