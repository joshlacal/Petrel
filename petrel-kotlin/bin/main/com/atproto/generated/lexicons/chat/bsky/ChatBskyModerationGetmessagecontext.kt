// Lexicon: 1, ID: chat.bsky.moderation.getMessageContext

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyModerationGetMessageContextDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.getMessageContext"
}

@Serializable
sealed interface ChatBskyModerationGetMessageContextOutputMessagesUnion {
    @Serializable
    @SerialName("chat.bsky.moderation.getMessageContext#ChatBskyConvoDefsMessageView")
    data class ChatBskyConvoDefsMessageView(val value: ChatBskyConvoDefsMessageView) : ChatBskyModerationGetMessageContextOutputMessagesUnion

    @Serializable
    @SerialName("chat.bsky.moderation.getMessageContext#ChatBskyConvoDefsDeletedMessageView")
    data class ChatBskyConvoDefsDeletedMessageView(val value: ChatBskyConvoDefsDeletedMessageView) : ChatBskyModerationGetMessageContextOutputMessagesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyModerationGetMessageContextOutputMessagesUnion
}

@Serializable
    data class ChatBskyModerationGetMessageContextParameters(
// Conversation that the message is from. NOTE: this field will eventually be required.        @SerialName("convoId")
        val convoId: String? = null,        @SerialName("messageId")
        val messageId: String,        @SerialName("before")
        val before: Int? = null,        @SerialName("after")
        val after: Int? = null    )

    @Serializable
    data class ChatBskyModerationGetMessageContextOutput(
        @SerialName("messages")
        val messages: List<ChatBskyModerationGetMessageContextOutputMessagesUnion>    )

/**
 * 
 *
 * Endpoint: chat.bsky.moderation.getMessageContext
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.getMessageContext(
parameters: ChatBskyModerationGetMessageContextParameters): ATProtoResponse<ChatBskyModerationGetMessageContextOutput> {
    val endpoint = "chat.bsky.moderation.getMessageContext"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
