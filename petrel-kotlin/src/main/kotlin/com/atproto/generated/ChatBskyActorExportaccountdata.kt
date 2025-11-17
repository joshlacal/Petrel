// Lexicon: 1, ID: chat.bsky.actor.exportAccountData

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyActorExportaccountdata {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.exportAccountData"

        @Serializable
    data class Output(
        @SerialName("data")
        val `data`: ByteArray    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.actor.exportAccountData
 */
suspend fun ATProtoClient.Chat.Bsky.Actor.exportaccountdata(
): ATProtoResponse<ChatBskyActorExportaccountdata.Output> {
    val endpoint = "chat.bsky.actor.exportAccountData"

    val queryParams: Map<String, String>? = null

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/jsonl"),
        body = null
    )
}
