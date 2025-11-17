// Lexicon: 1, ID: chat.bsky.convo.updateAllRead

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoUpdateallread {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.updateAllRead"

    @Serializable
    data class Input(
        @SerialName("status")
        val status: String? = null    )

        @Serializable
    data class Output(
// The count of updated convos.        @SerialName("updatedCount")
        val updatedCount: Int    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.updateAllRead
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.updateallread(
input: ChatBskyConvoUpdateallread.Input): ATProtoResponse<ChatBskyConvoUpdateallread.Output> {
    val endpoint = "chat.bsky.convo.updateAllRead"

    // JSON serialization
    val body = Json.encodeToString(input)
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
