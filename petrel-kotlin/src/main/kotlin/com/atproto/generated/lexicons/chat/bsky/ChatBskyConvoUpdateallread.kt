// Lexicon: 1, ID: chat.bsky.convo.updateAllRead

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoUpdateAllReadDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.updateAllRead"
}

@Serializable
    data class ChatBskyConvoUpdateAllReadInput(
        @SerialName("status")
        val status: String? = null    )

    @Serializable
    data class ChatBskyConvoUpdateAllReadOutput(
// The count of updated convos.        @SerialName("updatedCount")
        val updatedCount: Int    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.updateAllRead
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.updateAllRead(
input: ChatBskyConvoUpdateAllReadInput): ATProtoResponse<ChatBskyConvoUpdateAllReadOutput> {
    val endpoint = "chat.bsky.convo.updateAllRead"

    // JSON serialization
    val body = Json.encodeToString(input)
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
