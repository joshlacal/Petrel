// Lexicon: 1, ID: chat.bsky.convo.unmuteConvo

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoUnmuteconvo {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.unmuteConvo"

    @Serializable
    data class Input(
        @SerialName("convoId")
        val convoId: String    )

        @Serializable
    data class Output(
        @SerialName("convo")
        val convo: ChatBskyConvoDefs.Convoview    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.unmuteConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.unmuteconvo(
input: ChatBskyConvoUnmuteconvo.Input): ATProtoResponse<ChatBskyConvoUnmuteconvo.Output> {
    val endpoint = "chat.bsky.convo.unmuteConvo"

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
