// Lexicon: 1, ID: chat.bsky.convo.listConvos

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoListConvosDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.listConvos"
}

@Serializable
    data class ChatBskyConvoListConvosParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("readState")
        val readState: String? = null,        @SerialName("status")
        val status: String? = null    )

    @Serializable
    data class ChatBskyConvoListConvosOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("convos")
        val convos: List<ChatBskyConvoDefsConvoView>    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.listConvos
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.listConvos(
parameters: ChatBskyConvoListConvosParameters): ATProtoResponse<ChatBskyConvoListConvosOutput> {
    val endpoint = "chat.bsky.convo.listConvos"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
