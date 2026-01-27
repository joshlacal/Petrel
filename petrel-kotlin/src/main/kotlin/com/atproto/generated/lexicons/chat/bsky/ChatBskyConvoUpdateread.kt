// Lexicon: 1, ID: chat.bsky.convo.updateRead

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoUpdateReadDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.updateRead"
}

@Serializable
    data class ChatBskyConvoUpdateReadInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String? = null    )

    @Serializable
    data class ChatBskyConvoUpdateReadOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.updateRead
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.updateRead(
input: ChatBskyConvoUpdateReadInput): ATProtoResponse<ChatBskyConvoUpdateReadOutput> {
    val endpoint = "chat.bsky.convo.updateRead"

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
