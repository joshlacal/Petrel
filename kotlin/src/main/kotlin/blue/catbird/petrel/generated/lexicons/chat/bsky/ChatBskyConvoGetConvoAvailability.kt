// Lexicon: 1, ID: chat.bsky.convo.getConvoAvailability
// Check whether the requester and the other members can start a 1-1 chat. Only applicable to direct (non-group) conversations. If an existing convo is found for these members, it is returned. Does not create a new convo if it doesn't exist.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetConvoAvailabilityDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getConvoAvailability"
}

@Serializable
    data class ChatBskyConvoGetConvoAvailabilityParameters(
        @SerialName("members")
        val members: List<DID>    )

    @Serializable
    data class ChatBskyConvoGetConvoAvailabilityOutput(
        @SerialName("canChat")
        val canChat: Boolean,        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView? = null    )

/**
 * Check whether the requester and the other members can start a 1-1 chat. Only applicable to direct (non-group) conversations. If an existing convo is found for these members, it is returned. Does not create a new convo if it doesn't exist.
 *
 * Endpoint: chat.bsky.convo.getConvoAvailability
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getConvoAvailability(
parameters: ChatBskyConvoGetConvoAvailabilityParameters): ATProtoResponse<ChatBskyConvoGetConvoAvailabilityOutput> {
    val endpoint = "chat.bsky.convo.getConvoAvailability"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
