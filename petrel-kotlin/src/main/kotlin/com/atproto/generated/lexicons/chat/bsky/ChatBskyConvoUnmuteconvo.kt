// Lexicon: 1, ID: chat.bsky.convo.unmuteConvo

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoUnmuteConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.unmuteConvo"
}

@Serializable
    data class ChatBskyConvoUnmuteConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoUnmuteConvoOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.unmuteConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.unmuteConvo(
input: ChatBskyConvoUnmuteConvoInput): ATProtoResponse<ChatBskyConvoUnmuteConvoOutput> {
    val endpoint = "chat.bsky.convo.unmuteConvo"

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
