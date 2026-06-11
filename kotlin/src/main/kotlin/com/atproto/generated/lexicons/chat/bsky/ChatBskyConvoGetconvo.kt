// Lexicon: 1, ID: chat.bsky.convo.getConvo
// Gets an existing conversation by its ID.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getConvo"
}

@Serializable
    data class ChatBskyConvoGetConvoParameters(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoGetConvoOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyConvoGetConvoError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoGetConvoError("InvalidConvo", "")
    }

/**
 * Gets an existing conversation by its ID.
 *
 * Endpoint: chat.bsky.convo.getConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getConvo(
parameters: ChatBskyConvoGetConvoParameters): ATProtoResponse<ChatBskyConvoGetConvoOutput> {
    val endpoint = "chat.bsky.convo.getConvo"

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
