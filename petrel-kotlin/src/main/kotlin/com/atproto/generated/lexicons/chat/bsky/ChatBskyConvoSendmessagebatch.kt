// Lexicon: 1, ID: chat.bsky.convo.sendMessageBatch

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoSendMessageBatchDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.sendMessageBatch"
}

    @Serializable
    data class ChatBskyConvoSendMessageBatchBatchItem(
        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsMessageInput    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoSendMessageBatchBatchItem"
        }
    }

@Serializable
    data class ChatBskyConvoSendMessageBatchInput(
        @SerialName("items")
        val items: List<ChatBskyConvoSendMessageBatchBatchItem>    )

    @Serializable
    data class ChatBskyConvoSendMessageBatchOutput(
        @SerialName("items")
        val items: List<ChatBskyConvoDefsMessageView>    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.sendMessageBatch
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.sendMessageBatch(
input: ChatBskyConvoSendMessageBatchInput): ATProtoResponse<ChatBskyConvoSendMessageBatchOutput> {
    val endpoint = "chat.bsky.convo.sendMessageBatch"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
