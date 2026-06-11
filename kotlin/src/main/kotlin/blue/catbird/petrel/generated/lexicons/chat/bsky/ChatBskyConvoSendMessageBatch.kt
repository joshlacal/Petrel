// Lexicon: 1, ID: chat.bsky.convo.sendMessageBatch
// Sends a batch of messages to a conversation.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoSendMessageBatchDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.sendMessageBatch"
}

    @Serializable
    data class ChatBskyConvoSendMessageBatchBatchItem(
        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsMessageInput    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoSendMessageBatchBatchItem"
        }
    }

@Serializable
    data class ChatBskyConvoSendMessageBatchInput(
        @SerialName("items")
        val items: List<ChatBskyConvoSendMessageBatchBatchItem>    )

    @Serializable
    data class ChatBskyConvoSendMessageBatchOutput(
        @SerialName("items")
        val items: List<ChatBskyConvoDefsMessageView>    )

sealed class ChatBskyConvoSendMessageBatchError(val name: String, val description: String?) {
        object ConvoLocked: ChatBskyConvoSendMessageBatchError("ConvoLocked", "")
        object InvalidConvo: ChatBskyConvoSendMessageBatchError("InvalidConvo", "")
    }

/**
 * Sends a batch of messages to a conversation.
 *
 * Endpoint: chat.bsky.convo.sendMessageBatch
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.sendMessageBatch(
input: ChatBskyConvoSendMessageBatchInput): ATProtoResponse<ChatBskyConvoSendMessageBatchOutput> {
    val endpoint = "chat.bsky.convo.sendMessageBatch"

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
