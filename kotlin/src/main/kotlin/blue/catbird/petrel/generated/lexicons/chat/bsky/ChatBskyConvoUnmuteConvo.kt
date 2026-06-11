// Lexicon: 1, ID: chat.bsky.convo.unmuteConvo
// Unmutes a conversation, allowing notifications related to it.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoUnmuteConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.unmuteConvo"
}

@Serializable
    data class ChatBskyConvoUnmuteConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoUnmuteConvoOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyConvoUnmuteConvoError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoUnmuteConvoError("InvalidConvo", "")
    }

/**
 * Unmutes a conversation, allowing notifications related to it.
 *
 * Endpoint: chat.bsky.convo.unmuteConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.unmuteConvo(
input: ChatBskyConvoUnmuteConvoInput): ATProtoResponse<ChatBskyConvoUnmuteConvoOutput> {
    val endpoint = "chat.bsky.convo.unmuteConvo"

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
