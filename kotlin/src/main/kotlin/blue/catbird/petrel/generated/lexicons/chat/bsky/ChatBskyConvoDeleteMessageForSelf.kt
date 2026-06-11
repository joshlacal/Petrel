// Lexicon: 1, ID: chat.bsky.convo.deleteMessageForSelf
// Marks a message as deleted for the viewer, so they won't see that message in future enumerations.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoDeleteMessageForSelfDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.deleteMessageForSelf"
}

@Serializable
    data class ChatBskyConvoDeleteMessageForSelfInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String    )

    typealias ChatBskyConvoDeleteMessageForSelfOutput = ChatBskyConvoDefsDeletedMessageView

sealed class ChatBskyConvoDeleteMessageForSelfError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoDeleteMessageForSelfError("InvalidConvo", "")
        object MessageDeleteNotAllowed: ChatBskyConvoDeleteMessageForSelfError("MessageDeleteNotAllowed", "Indicates that this message cannot be deleted, e.g. because it is a system message.")
    }

/**
 * Marks a message as deleted for the viewer, so they won't see that message in future enumerations.
 *
 * Endpoint: chat.bsky.convo.deleteMessageForSelf
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.deleteMessageForSelf(
input: ChatBskyConvoDeleteMessageForSelfInput): ATProtoResponse<ChatBskyConvoDeleteMessageForSelfOutput> {
    val endpoint = "chat.bsky.convo.deleteMessageForSelf"

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
