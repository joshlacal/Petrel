// Lexicon: 1, ID: chat.bsky.convo.sendMessage

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoSendmessage {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.sendMessage"

    @Serializable
    data class Input(
        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefs.Messageinput    )

        typealias Output = ChatBskyConvoDefs.Messageview

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.sendMessage
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.sendmessage(
input: ChatBskyConvoSendmessage.Input): ATProtoResponse<ChatBskyConvoSendmessage.Output> {
    val endpoint = "chat.bsky.convo.sendMessage"

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
