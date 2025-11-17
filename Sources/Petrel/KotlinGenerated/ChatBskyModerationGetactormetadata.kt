// Lexicon: 1, ID: chat.bsky.moderation.getActorMetadata

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyModerationGetactormetadata {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.getActorMetadata"

    @Serializable
    data class Parameters(
        @SerialName("actor")
        val actor: DID    )

        @Serializable
    data class Output(
        @SerialName("day")
        val day: Metadata,        @SerialName("month")
        val month: Metadata,        @SerialName("all")
        val all: Metadata    )

        @Serializable
    data class Metadata(
        @SerialName("messagesSent")
        val messagesSent: Int,        @SerialName("messagesReceived")
        val messagesReceived: Int,        @SerialName("convos")
        val convos: Int,        @SerialName("convosStarted")
        val convosStarted: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#metadata"
        }
    }

}

/**
 * 
 *
 * Endpoint: chat.bsky.moderation.getActorMetadata
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.getactormetadata(
parameters: ChatBskyModerationGetactormetadata.Parameters): ATProtoResponse<ChatBskyModerationGetactormetadata.Output> {
    val endpoint = "chat.bsky.moderation.getActorMetadata"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
