// Lexicon: 1, ID: chat.bsky.convo.getConvoAvailability
// Get whether the requester and the other members can chat. If an existing convo is found for these members, it is returned.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetConvoAvailabilityDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getConvoAvailability"
}

@Serializable
    data class ChatBskyConvoGetConvoAvailabilityParameters(
        @SerialName("members")
        val members: List<DID>    )

    @Serializable
    data class ChatBskyConvoGetConvoAvailabilityOutput(
        @SerialName("canChat")
        val canChat: Boolean,        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView? = null    )

/**
 * Get whether the requester and the other members can chat. If an existing convo is found for these members, it is returned.
 *
 * Endpoint: chat.bsky.convo.getConvoAvailability
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getConvoAvailability(
parameters: ChatBskyConvoGetConvoAvailabilityParameters): ATProtoResponse<ChatBskyConvoGetConvoAvailabilityOutput> {
    val endpoint = "chat.bsky.convo.getConvoAvailability"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
