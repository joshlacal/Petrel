// Lexicon: 1, ID: chat.bsky.convo.listConvos

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoListconvos {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.listConvos"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("readState")
        val readState: String? = null,        @SerialName("status")
        val status: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("convos")
        val convos: List<ChatBskyConvoDefs.Convoview>    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.listConvos
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.listconvos(
parameters: ChatBskyConvoListconvos.Parameters): ATProtoResponse<ChatBskyConvoListconvos.Output> {
    val endpoint = "chat.bsky.convo.listConvos"

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
