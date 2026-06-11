// Lexicon: 1, ID: chat.bsky.moderation.getConvo
// [NOTE: This is under active development and should be considered unstable while this note is here]. Gets an existing conversation by its ID, for moderation purposes. Does not require the requester to be a member of the conversation.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyModerationGetConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.getConvo"
}

@Serializable
    data class ChatBskyModerationGetConvoParameters(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyModerationGetConvoOutput(
        @SerialName("convo")
        val convo: ChatBskyModerationDefsConvoView    )

sealed class ChatBskyModerationGetConvoError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyModerationGetConvoError("InvalidConvo", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Gets an existing conversation by its ID, for moderation purposes. Does not require the requester to be a member of the conversation.
 *
 * Endpoint: chat.bsky.moderation.getConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.getConvo(
parameters: ChatBskyModerationGetConvoParameters): ATProtoResponse<ChatBskyModerationGetConvoOutput> {
    val endpoint = "chat.bsky.moderation.getConvo"

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
