// Lexicon: 1, ID: chat.bsky.convo.unmuteConvo
// Unmutes a conversation, allowing notifications related to it.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoUnmuteConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.unmuteConvo"
}

@Serializable
    data class ChatBskyConvoUnmuteConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoUnmuteConvoOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyConvoUnmuteConvoError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoUnmuteConvoError("InvalidConvo", "")
    }

/**
 * Unmutes a conversation, allowing notifications related to it.
 *
 * Endpoint: chat.bsky.convo.unmuteConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.unmuteConvo(
input: ChatBskyConvoUnmuteConvoInput): ATProtoResponse<ChatBskyConvoUnmuteConvoOutput> {
    val endpoint = "chat.bsky.convo.unmuteConvo"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
