// Lexicon: 1, ID: chat.bsky.moderation.updateActorAccess

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyModerationUpdateactoraccess {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.updateActorAccess"

    @Serializable
    data class Input(
        @SerialName("actor")
        val actor: DID,        @SerialName("allowAccess")
        val allowAccess: Boolean,        @SerialName("ref")
        val ref: String? = null    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.moderation.updateActorAccess
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.updateactoraccess(
input: ChatBskyModerationUpdateactoraccess.Input): ATProtoResponse<Unit> {
    val endpoint = "chat.bsky.moderation.updateActorAccess"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
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
