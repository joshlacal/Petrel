// Lexicon: 1, ID: chat.bsky.convo.addReaction
// Adds an emoji reaction to a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in a single reaction.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoAddReactionDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.addReaction"
}

@Serializable
    data class ChatBskyConvoAddReactionInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String,        @SerialName("value")
        val value: String    )

    @Serializable
    data class ChatBskyConvoAddReactionOutput(
        @SerialName("message")
        val message: ChatBskyConvoDefsMessageView    )

sealed class ChatBskyConvoAddReactionError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoAddReactionError("InvalidConvo", "")
        object ReactionNotAllowed: ChatBskyConvoAddReactionError("ReactionNotAllowed", "Indicates that reactions are not allowed on this message, e.g. because it is a system message.")
        object ReactionMessageDeleted: ChatBskyConvoAddReactionError("ReactionMessageDeleted", "Indicates that the message has been deleted and reactions can no longer be added/removed.")
        object ReactionLimitReached: ChatBskyConvoAddReactionError("ReactionLimitReached", "Indicates that the message has the maximum number of reactions allowed for a single user, and the requested reaction wasn't yet present. If it was already present, the request will not fail since it is idempotent.")
        object ReactionInvalidValue: ChatBskyConvoAddReactionError("ReactionInvalidValue", "Indicates the value for the reaction is not acceptable. In general, this means it is not an emoji.")
    }

/**
 * Adds an emoji reaction to a message. Requires authentication. It is idempotent, so multiple calls from the same user with the same emoji result in a single reaction.
 *
 * Endpoint: chat.bsky.convo.addReaction
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.addReaction(
input: ChatBskyConvoAddReactionInput): ATProtoResponse<ChatBskyConvoAddReactionOutput> {
    val endpoint = "chat.bsky.convo.addReaction"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
