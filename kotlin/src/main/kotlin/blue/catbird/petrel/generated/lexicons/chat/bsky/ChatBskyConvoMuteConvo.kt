// Lexicon: 1, ID: chat.bsky.convo.muteConvo
// Mutes a conversation, preventing notifications related to it.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoMuteConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.muteConvo"
}

@Serializable
    data class ChatBskyConvoMuteConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoMuteConvoOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyConvoMuteConvoError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoMuteConvoError("InvalidConvo", "")
    }

/**
 * Mutes a conversation, preventing notifications related to it.
 *
 * Endpoint: chat.bsky.convo.muteConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.muteConvo(
input: ChatBskyConvoMuteConvoInput): ATProtoResponse<ChatBskyConvoMuteConvoOutput> {
    val endpoint = "chat.bsky.convo.muteConvo"

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
