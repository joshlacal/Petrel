// Lexicon: 1, ID: chat.bsky.convo.muteConvo

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoMuteConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.muteConvo"
}

@Serializable
    data class ChatBskyConvoMuteConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoMuteConvoOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.muteConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.muteConvo(
input: ChatBskyConvoMuteConvoInput): ATProtoResponse<ChatBskyConvoMuteConvoOutput> {
    val endpoint = "chat.bsky.convo.muteConvo"

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
