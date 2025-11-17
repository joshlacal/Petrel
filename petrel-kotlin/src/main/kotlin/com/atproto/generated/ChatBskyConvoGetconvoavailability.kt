// Lexicon: 1, ID: chat.bsky.convo.getConvoAvailability
// Get whether the requester and the other members can chat. If an existing convo is found for these members, it is returned.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoGetconvoavailability {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getConvoAvailability"

    @Serializable
    data class Parameters(
        @SerialName("members")
        val members: List<DID>    )

        @Serializable
    data class Output(
        @SerialName("canChat")
        val canChat: Boolean,        @SerialName("convo")
        val convo: ChatBskyConvoDefs.Convoview? = null    )

}

/**
 * Get whether the requester and the other members can chat. If an existing convo is found for these members, it is returned.
 *
 * Endpoint: chat.bsky.convo.getConvoAvailability
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getconvoavailability(
parameters: ChatBskyConvoGetconvoavailability.Parameters): ATProtoResponse<ChatBskyConvoGetconvoavailability.Output> {
    val endpoint = "chat.bsky.convo.getConvoAvailability"

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
