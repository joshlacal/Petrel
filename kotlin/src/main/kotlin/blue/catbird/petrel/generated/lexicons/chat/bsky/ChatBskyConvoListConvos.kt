// Lexicon: 1, ID: chat.bsky.convo.listConvos
// Returns a page of conversations (direct or group) for the user.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoListConvosDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.listConvos"
}

@Serializable
    data class ChatBskyConvoListConvosParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("readState")
        val readState: String? = null,// Filter convos by their status. It is discouraged to call with "request" and preferred to call chat.bsky.convo.listConvoRequests, which also includes group join requests made by the user.        @SerialName("status")
        val status: String? = null,// Filter by conversation kind.        @SerialName("kind")
        val kind: String? = null,// Filter by conversation lock status. Values follow chat.bsky.convo.defs#convoLockStatus.        @SerialName("lockStatus")
        val lockStatus: String? = null    )

    @Serializable
    data class ChatBskyConvoListConvosOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("convos")
        val convos: List<ChatBskyConvoDefsConvoView>    )

/**
 * Returns a page of conversations (direct or group) for the user.
 *
 * Endpoint: chat.bsky.convo.listConvos
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.listConvos(
parameters: ChatBskyConvoListConvosParameters): ATProtoResponse<ChatBskyConvoListConvosOutput> {
    val endpoint = "chat.bsky.convo.listConvos"

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
