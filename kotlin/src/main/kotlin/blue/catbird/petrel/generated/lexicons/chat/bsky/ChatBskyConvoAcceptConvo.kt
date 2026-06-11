// Lexicon: 1, ID: chat.bsky.convo.acceptConvo
// Marks a conversation as accepted, so it is shown in the list of accepted convos instead on the request convos.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoAcceptConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.acceptConvo"
}

@Serializable
    data class ChatBskyConvoAcceptConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoAcceptConvoOutput(
// Rev when the convo was accepted. If not present, the convo was already accepted.        @SerialName("rev")
        val rev: String? = null    )

sealed class ChatBskyConvoAcceptConvoError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoAcceptConvoError("InvalidConvo", "")
    }

/**
 * Marks a conversation as accepted, so it is shown in the list of accepted convos instead on the request convos.
 *
 * Endpoint: chat.bsky.convo.acceptConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.acceptConvo(
input: ChatBskyConvoAcceptConvoInput): ATProtoResponse<ChatBskyConvoAcceptConvoOutput> {
    val endpoint = "chat.bsky.convo.acceptConvo"

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
