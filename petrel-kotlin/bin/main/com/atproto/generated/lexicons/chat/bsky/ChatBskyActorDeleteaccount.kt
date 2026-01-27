// Lexicon: 1, ID: chat.bsky.actor.deleteAccount

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyActorDeleteAccountDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.deleteAccount"
}

    @Serializable
    class ChatBskyActorDeleteAccountOutput

/**
 * 
 *
 * Endpoint: chat.bsky.actor.deleteAccount
 */
suspend fun ATProtoClient.Chat.Bsky.Actor.deleteAccount(
): ATProtoResponse<ChatBskyActorDeleteAccountOutput> {
    val endpoint = "chat.bsky.actor.deleteAccount"

    val body: String? = null
    val contentType = "application/json"

    return client.networkService.performRequest(
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
