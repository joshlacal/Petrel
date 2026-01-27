// Lexicon: 1, ID: chat.bsky.convo.leaveConvo

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoLeaveConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.leaveConvo"
}

@Serializable
    data class ChatBskyConvoLeaveConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoLeaveConvoOutput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("rev")
        val rev: String    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.leaveConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.leaveConvo(
input: ChatBskyConvoLeaveConvoInput): ATProtoResponse<ChatBskyConvoLeaveConvoOutput> {
    val endpoint = "chat.bsky.convo.leaveConvo"

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
