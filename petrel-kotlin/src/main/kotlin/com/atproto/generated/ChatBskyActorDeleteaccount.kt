// Lexicon: 1, ID: chat.bsky.actor.deleteAccount

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyActorDeleteaccount {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.deleteAccount"

        @Serializable
    data class Output(
    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.actor.deleteAccount
 */
suspend fun ATProtoClient.Chat.Bsky.Actor.deleteaccount(
): ATProtoResponse<ChatBskyActorDeleteaccount.Output> {
    val endpoint = "chat.bsky.actor.deleteAccount"

    val body: String? = null
    val contentType = "application/json"

    return networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
