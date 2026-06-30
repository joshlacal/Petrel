// Lexicon: 1, ID: chat.bsky.convo.sendMessage
// Sends a message to a conversation.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoSendMessageDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.sendMessage"
}

@Serializable
    data class ChatBskyConvoSendMessageInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsMessageInput    )

    typealias ChatBskyConvoSendMessageOutput = ChatBskyConvoDefsMessageView

sealed class ChatBskyConvoSendMessageError(val name: String, val description: String?) {
        object ConvoLocked: ChatBskyConvoSendMessageError("ConvoLocked", "")
        object InvalidConvo: ChatBskyConvoSendMessageError("InvalidConvo", "")
        object ReplyTargetNotFound: ChatBskyConvoSendMessageError("ReplyTargetNotFound", "")
    }

/**
 * Sends a message to a conversation.
 *
 * Endpoint: chat.bsky.convo.sendMessage
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.sendMessage(
input: ChatBskyConvoSendMessageInput): ATProtoResponse<ChatBskyConvoSendMessageOutput> {
    val endpoint = "chat.bsky.convo.sendMessage"

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
