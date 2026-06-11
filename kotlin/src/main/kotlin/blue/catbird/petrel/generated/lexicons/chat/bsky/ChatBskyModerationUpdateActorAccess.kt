// Lexicon: 1, ID: chat.bsky.moderation.updateActorAccess

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyModerationUpdateActorAccessDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.updateActorAccess"
}

@Serializable
    data class ChatBskyModerationUpdateActorAccessInput(
        @SerialName("actor")
        val actor: DID,        @SerialName("allowAccess")
        val allowAccess: Boolean,        @SerialName("ref")
        val ref: String? = null    )

/**
 * 
 *
 * Endpoint: chat.bsky.moderation.updateActorAccess
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.updateActorAccess(
input: ChatBskyModerationUpdateActorAccessInput): ATProtoResponse<Unit> {
    val endpoint = "chat.bsky.moderation.updateActorAccess"

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
            "Accept" to "None"
        ),
        body = body
    )
}
