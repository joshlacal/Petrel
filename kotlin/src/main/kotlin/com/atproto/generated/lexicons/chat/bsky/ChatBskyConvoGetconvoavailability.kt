// Lexicon: 1, ID: chat.bsky.convo.getConvoAvailability
// Check whether the requester and the other members can start a 1-1 chat. Only applicable to direct (non-group) conversations. If an existing convo is found for these members, it is returned. Does not create a new convo if it doesn't exist.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
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
 * Check whether the requester and the other members can start a 1-1 chat. Only applicable to direct (non-group) conversations. If an existing convo is found for these members, it is returned. Does not create a new convo if it doesn't exist.
 *
 * Endpoint: chat.bsky.convo.getConvoAvailability
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getConvoAvailability(
parameters: ChatBskyConvoGetConvoAvailabilityParameters): ATProtoResponse<ChatBskyConvoGetConvoAvailabilityOutput> {
    val endpoint = "chat.bsky.convo.getConvoAvailability"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
