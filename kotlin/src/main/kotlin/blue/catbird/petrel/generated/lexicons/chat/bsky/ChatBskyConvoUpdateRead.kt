// Lexicon: 1, ID: chat.bsky.convo.updateRead
// Updates the read state of a conversation from, optionally specifying the last read message.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoUpdateReadDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.updateRead"
}

@Serializable
    data class ChatBskyConvoUpdateReadInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String? = null    )

    @Serializable
    data class ChatBskyConvoUpdateReadOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyConvoUpdateReadError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoUpdateReadError("InvalidConvo", "")
    }

/**
 * Updates the read state of a conversation from, optionally specifying the last read message.
 *
 * Endpoint: chat.bsky.convo.updateRead
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.updateRead(
input: ChatBskyConvoUpdateReadInput): ATProtoResponse<ChatBskyConvoUpdateReadOutput> {
    val endpoint = "chat.bsky.convo.updateRead"

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
