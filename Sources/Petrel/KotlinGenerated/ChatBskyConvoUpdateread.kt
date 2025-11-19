// Lexicon: 1, ID: chat.bsky.convo.updateRead

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoUpdateread {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.updateRead"

    @Serializable
    data class Input(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String? = null    )

        @Serializable
    data class Output(
        @SerialName("convo")
        val convo: ChatBskyConvoDefs.Convoview    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.updateRead
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.updateread(
input: ChatBskyConvoUpdateread.Input): ATProtoResponse<ChatBskyConvoUpdateread.Output> {
    val endpoint = "chat.bsky.convo.updateRead"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
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
