// Lexicon: 1, ID: chat.bsky.actor.exportAccountData

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyActorExportAccountDataDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.exportAccountData"
}

    @Serializable
    data class ChatBskyActorExportAccountDataOutput(
        @SerialName("data")
        val `data`: ByteArray    )

/**
 * 
 *
 * Endpoint: chat.bsky.actor.exportAccountData
 */
suspend fun ATProtoClient.Chat.Bsky.Actor.exportAccountData(
): ATProtoResponse<ChatBskyActorExportAccountDataOutput> {
    val endpoint = "chat.bsky.actor.exportAccountData"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/jsonl"),
        body = null
    )
}
