// Lexicon: 1, ID: chat.bsky.convo.updateAllRead
// Sets conversations from a user as read to the latest message, with filters.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoUpdateAllReadDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.updateAllRead"
}

@Serializable
    data class ChatBskyConvoUpdateAllReadInput(
        @SerialName("status")
        val status: String? = null    )

    @Serializable
    data class ChatBskyConvoUpdateAllReadOutput(
// The count of updated convos.        @SerialName("updatedCount")
        val updatedCount: Int    )

/**
 * Sets conversations from a user as read to the latest message, with filters.
 *
 * Endpoint: chat.bsky.convo.updateAllRead
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.updateAllRead(
input: ChatBskyConvoUpdateAllReadInput): ATProtoResponse<ChatBskyConvoUpdateAllReadOutput> {
    val endpoint = "chat.bsky.convo.updateAllRead"

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
