// Lexicon: 1, ID: chat.bsky.moderation.updateActorAccess

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyModerationUpdateActorAccessDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.updateActorAccess"
}

@Serializable
    data class ChatBskyModerationUpdateActorAccessInput(
        @SerialName("actor")
        val actor: DID,        @SerialName("allowAccess")
        val allowAccess: Boolean,        @SerialName("ref")
        val ref: String? = null    )

/**
 * 
 *
 * Endpoint: chat.bsky.moderation.updateActorAccess
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.updateActorAccess(
input: ChatBskyModerationUpdateActorAccessInput): ATProtoResponse<Unit> {
    val endpoint = "chat.bsky.moderation.updateActorAccess"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
