// Lexicon: 1, ID: chat.bsky.convo.deleteMessageForSelf

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoDeleteMessageForSelfDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.deleteMessageForSelf"
}

@Serializable
    data class ChatBskyConvoDeleteMessageForSelfInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String    )

    typealias ChatBskyConvoDeleteMessageForSelfOutput = ChatBskyConvoDefsDeletedMessageView

/**
 * 
 *
 * Endpoint: chat.bsky.convo.deleteMessageForSelf
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.deleteMessageForSelf(
input: ChatBskyConvoDeleteMessageForSelfInput): ATProtoResponse<ChatBskyConvoDeleteMessageForSelfOutput> {
    val endpoint = "chat.bsky.convo.deleteMessageForSelf"

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
