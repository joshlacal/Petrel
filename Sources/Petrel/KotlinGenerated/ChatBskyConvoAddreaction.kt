// Lexicon: 1, ID: chat.bsky.convo.addReaction
// Adds an emoji reaction to a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in a single reaction.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoAddreaction {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.addReaction"

    @Serializable
    data class Input(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String,        @SerialName("value")
        val value: String    )

        @Serializable
    data class Output(
        @SerialName("message")
        val message: ChatBskyConvoDefs.Messageview    )

    sealed class Error(val name: String, val description: String?) {
        object Reactionmessagedeleted: Error("ReactionMessageDeleted", "Indicates that the message has been deleted and reactions can no longer be added/removed.")
        object Reactionlimitreached: Error("ReactionLimitReached", "Indicates that the message has the maximum number of reactions allowed for a single user, and the requested reaction wasn't yet present. If it was already present, the request will not fail since it is idempotent.")
        object Reactioninvalidvalue: Error("ReactionInvalidValue", "Indicates the value for the reaction is not acceptable. In general, this means it is not an emoji.")
    }

}

/**
 * Adds an emoji reaction to a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in a single reaction.
 *
 * Endpoint: chat.bsky.convo.addReaction
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.addreaction(
input: ChatBskyConvoAddreaction.Input): ATProtoResponse<ChatBskyConvoAddreaction.Output> {
    val endpoint = "chat.bsky.convo.addReaction"

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
