// Lexicon: 1, ID: chat.bsky.convo.getConvoForMembers

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoGetconvoformembers {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getConvoForMembers"

    @Serializable
    data class Parameters(
        @SerialName("members")
        val members: List<DID>    )

        @Serializable
    data class Output(
        @SerialName("convo")
        val convo: ChatBskyConvoDefs.Convoview    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.getConvoForMembers
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getconvoformembers(
parameters: ChatBskyConvoGetconvoformembers.Parameters): ATProtoResponse<ChatBskyConvoGetconvoformembers.Output> {
    val endpoint = "chat.bsky.convo.getConvoForMembers"

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
