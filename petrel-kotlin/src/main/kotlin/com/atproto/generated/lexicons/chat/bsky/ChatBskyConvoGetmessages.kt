// Lexicon: 1, ID: chat.bsky.convo.getMessages

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetMessagesDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getMessages"
}

@Serializable
sealed interface ChatBskyConvoGetMessagesOutputMessagesUnion {
    @Serializable
    @SerialName("chat.bsky.convo.getMessages#ChatBskyConvoDefsMessageView")
    data class ChatBskyConvoDefsMessageView(val value: ChatBskyConvoDefsMessageView) : ChatBskyConvoGetMessagesOutputMessagesUnion

    @Serializable
    @SerialName("chat.bsky.convo.getMessages#ChatBskyConvoDefsDeletedMessageView")
    data class ChatBskyConvoDefsDeletedMessageView(val value: ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoGetMessagesOutputMessagesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoGetMessagesOutputMessagesUnion
}

@Serializable
    data class ChatBskyConvoGetMessagesParameters(
        @SerialName("convoId")
        val convoId: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ChatBskyConvoGetMessagesOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("messages")
        val messages: List<ChatBskyConvoGetMessagesOutputMessagesUnion>    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.getMessages
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getMessages(
parameters: ChatBskyConvoGetMessagesParameters): ATProtoResponse<ChatBskyConvoGetMessagesOutput> {
    val endpoint = "chat.bsky.convo.getMessages"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
