// Lexicon: 1, ID: chat.bsky.convo.sendMessage

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoSendMessageDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.sendMessage"
}

@Serializable
    data class ChatBskyConvoSendMessageInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsMessageInput    )

    typealias ChatBskyConvoSendMessageOutput = ChatBskyConvoDefsMessageView

/**
 * 
 *
 * Endpoint: chat.bsky.convo.sendMessage
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.sendMessage(
input: ChatBskyConvoSendMessageInput): ATProtoResponse<ChatBskyConvoSendMessageOutput> {
    val endpoint = "chat.bsky.convo.sendMessage"

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
