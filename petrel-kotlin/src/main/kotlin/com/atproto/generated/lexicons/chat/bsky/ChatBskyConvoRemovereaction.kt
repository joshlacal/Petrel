// Lexicon: 1, ID: chat.bsky.convo.removeReaction
// Removes an emoji reaction from a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in that reaction not being present, even if it already wasn't.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoRemoveReactionDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.removeReaction"
}

@Serializable
    data class ChatBskyConvoRemoveReactionInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String,        @SerialName("value")
        val value: String    )

    @Serializable
    data class ChatBskyConvoRemoveReactionOutput(
        @SerialName("message")
        val message: ChatBskyConvoDefsMessageView    )

sealed class ChatBskyConvoRemoveReactionError(val name: String, val description: String?) {
        object ReactionMessageDeleted: ChatBskyConvoRemoveReactionError("ReactionMessageDeleted", "Indicates that the message has been deleted and reactions can no longer be added/removed.")
        object ReactionInvalidValue: ChatBskyConvoRemoveReactionError("ReactionInvalidValue", "Indicates the value for the reaction is not acceptable. In general, this means it is not an emoji.")
    }

/**
 * Removes an emoji reaction from a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in that reaction not being present, even if it already wasn't.
 *
 * Endpoint: chat.bsky.convo.removeReaction
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.removeReaction(
input: ChatBskyConvoRemoveReactionInput): ATProtoResponse<ChatBskyConvoRemoveReactionOutput> {
    val endpoint = "chat.bsky.convo.removeReaction"

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
