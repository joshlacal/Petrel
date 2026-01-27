// Lexicon: 1, ID: chat.bsky.moderation.getActorMetadata

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyModerationGetActorMetadataDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.getActorMetadata"
}

    @Serializable
    data class ChatBskyModerationGetActorMetadataMetadata(
        @SerialName("messagesSent")
        val messagesSent: Int,        @SerialName("messagesReceived")
        val messagesReceived: Int,        @SerialName("convos")
        val convos: Int,        @SerialName("convosStarted")
        val convosStarted: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyModerationGetActorMetadataMetadata"
        }
    }

@Serializable
    data class ChatBskyModerationGetActorMetadataParameters(
        @SerialName("actor")
        val actor: DID    )

    @Serializable
    data class ChatBskyModerationGetActorMetadataOutput(
        @SerialName("day")
        val day: ChatBskyModerationGetActorMetadataMetadata,        @SerialName("month")
        val month: ChatBskyModerationGetActorMetadataMetadata,        @SerialName("all")
        val all: ChatBskyModerationGetActorMetadataMetadata    )

/**
 * 
 *
 * Endpoint: chat.bsky.moderation.getActorMetadata
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.getActorMetadata(
parameters: ChatBskyModerationGetActorMetadataParameters): ATProtoResponse<ChatBskyModerationGetActorMetadataOutput> {
    val endpoint = "chat.bsky.moderation.getActorMetadata"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
