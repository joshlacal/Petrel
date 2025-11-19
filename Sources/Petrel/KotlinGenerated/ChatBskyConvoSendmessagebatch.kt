// Lexicon: 1, ID: chat.bsky.convo.sendMessageBatch

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoSendmessagebatch {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.sendMessageBatch"

    @Serializable
    data class Input(
        @SerialName("items")
        val items: List<Batchitem>    )

        @Serializable
    data class Output(
        @SerialName("items")
        val items: List<ChatBskyConvoDefs.Messageview>    )

        @Serializable
    data class Batchitem(
        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefs.Messageinput    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#batchitem"
        }
    }

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.sendMessageBatch
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.sendmessagebatch(
input: ChatBskyConvoSendmessagebatch.Input): ATProtoResponse<ChatBskyConvoSendmessagebatch.Output> {
    val endpoint = "chat.bsky.convo.sendMessageBatch"

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
