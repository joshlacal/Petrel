// Lexicon: 1, ID: chat.bsky.convo.getConvo

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

/**
 * 
 *
 * Endpoint: chat.bsky.convo.getConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getConvo(
parameters: ChatBskyConvoGetConvoParameters): ATProtoResponse<ChatBskyConvoGetConvoOutput> {
    val endpoint = "chat.bsky.convo.getConvo"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
