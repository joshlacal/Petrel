// Lexicon: 1, ID: chat.bsky.convo.muteConvo

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoMuteconvo {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.muteConvo"

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
 * Endpoint: chat.bsky.convo.muteConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.muteconvo(
input: ChatBskyConvoMuteconvo.Input): ATProtoResponse<ChatBskyConvoMuteconvo.Output> {
    val endpoint = "chat.bsky.convo.muteConvo"

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
