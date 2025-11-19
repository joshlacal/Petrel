// Lexicon: 1, ID: chat.bsky.convo.getMessages

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface OutputMessagesUnion {
    @Serializable
    @SerialName("ChatBskyConvoDefs.Messageview")
    data class Messageview(val value: ChatBskyConvoDefs.Messageview) : OutputMessagesUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Deletedmessageview")
    data class Deletedmessageview(val value: ChatBskyConvoDefs.Deletedmessageview) : OutputMessagesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputMessagesUnion
}

object ChatBskyConvoGetmessages {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getMessages"

    @Serializable
    data class Parameters(
        @SerialName("convoId")
        val convoId: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("messages")
        val messages: List<OutputMessagesUnion>    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.getMessages
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getmessages(
parameters: ChatBskyConvoGetmessages.Parameters): ATProtoResponse<ChatBskyConvoGetmessages.Output> {
    val endpoint = "chat.bsky.convo.getMessages"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
