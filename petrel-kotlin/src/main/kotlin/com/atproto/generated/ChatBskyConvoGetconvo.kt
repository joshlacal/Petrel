// Lexicon: 1, ID: chat.bsky.convo.getConvo

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoGetconvo {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getConvo"

    @Serializable
    data class Parameters(
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
 * Endpoint: chat.bsky.convo.getConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getconvo(
parameters: ChatBskyConvoGetconvo.Parameters): ATProtoResponse<ChatBskyConvoGetconvo.Output> {
    val endpoint = "chat.bsky.convo.getConvo"

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
