// Lexicon: 1, ID: chat.bsky.moderation.getMessageContext

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

object ChatBskyModerationGetmessagecontext {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.getMessageContext"

    @Serializable
    data class Parameters(
// Conversation that the message is from. NOTE: this field will eventually be required.        @SerialName("convoId")
        val convoId: String? = null,        @SerialName("messageId")
        val messageId: String,        @SerialName("before")
        val before: Int? = null,        @SerialName("after")
        val after: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("messages")
        val messages: List<OutputMessagesUnion>    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.moderation.getMessageContext
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.getmessagecontext(
parameters: ChatBskyModerationGetmessagecontext.Parameters): ATProtoResponse<ChatBskyModerationGetmessagecontext.Output> {
    val endpoint = "chat.bsky.moderation.getMessageContext"

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
