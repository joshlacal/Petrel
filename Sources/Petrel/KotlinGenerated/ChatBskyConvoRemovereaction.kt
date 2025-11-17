// Lexicon: 1, ID: chat.bsky.convo.removeReaction
// Removes an emoji reaction from a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in that reaction not being present, even if it already wasn't.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyConvoRemovereaction {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.removeReaction"

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
        object Reactioninvalidvalue: Error("ReactionInvalidValue", "Indicates the value for the reaction is not acceptable. In general, this means it is not an emoji.")
    }

}

/**
 * Removes an emoji reaction from a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in that reaction not being present, even if it already wasn't.
 *
 * Endpoint: chat.bsky.convo.removeReaction
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.removereaction(
input: ChatBskyConvoRemovereaction.Input): ATProtoResponse<ChatBskyConvoRemovereaction.Output> {
    val endpoint = "chat.bsky.convo.removeReaction"

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
