// Lexicon: 1, ID: chat.bsky.convo.acceptConvo

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoAcceptconvo {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.acceptConvo"

    @Serializable
    data class Input(
        @SerialName("convoId")
        val convoId: String    )

        @Serializable
    data class Output(
// Rev when the convo was accepted. If not present, the convo was already accepted.        @SerialName("rev")
        val rev: String? = null    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.acceptConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.acceptconvo(
input: ChatBskyConvoAcceptconvo.Input): ATProtoResponse<ChatBskyConvoAcceptconvo.Output> {
    val endpoint = "chat.bsky.convo.acceptConvo"

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
