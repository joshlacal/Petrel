// Lexicon: 1, ID: chat.bsky.convo.deleteMessageForSelf

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoDeletemessageforself {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.deleteMessageForSelf"

    @Serializable
    data class Input(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String    )

        typealias Output = ChatBskyConvoDefs.Deletedmessageview

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.deleteMessageForSelf
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.deletemessageforself(
input: ChatBskyConvoDeletemessageforself.Input): ATProtoResponse<ChatBskyConvoDeletemessageforself.Output> {
    val endpoint = "chat.bsky.convo.deleteMessageForSelf"

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
