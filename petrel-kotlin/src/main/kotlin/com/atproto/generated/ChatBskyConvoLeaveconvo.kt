// Lexicon: 1, ID: chat.bsky.convo.leaveConvo

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoLeaveconvo {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.leaveConvo"

    @Serializable
    data class Input(
        @SerialName("convoId")
        val convoId: String    )

        @Serializable
    data class Output(
        @SerialName("convoId")
        val convoId: String,        @SerialName("rev")
        val rev: String    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.leaveConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.leaveconvo(
input: ChatBskyConvoLeaveconvo.Input): ATProtoResponse<ChatBskyConvoLeaveconvo.Output> {
    val endpoint = "chat.bsky.convo.leaveConvo"

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
