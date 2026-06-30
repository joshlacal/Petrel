// Lexicon: 1, ID: chat.bsky.moderation.getConvos
// Gets existing conversations by their IDs, for moderation purposes. Does not require the requester to be a member of the conversations. Unknown IDs are silently omitted from the response.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyModerationGetConvosDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.getConvos"
}

@Serializable
    data class ChatBskyModerationGetConvosParameters(
        @SerialName("convoIds")
        val convoIds: List<String>    )

    @Serializable
    data class ChatBskyModerationGetConvosOutput(
        @SerialName("convos")
        val convos: List<ChatBskyModerationDefsConvoView>    )

/**
 * Gets existing conversations by their IDs, for moderation purposes. Does not require the requester to be a member of the conversations. Unknown IDs are silently omitted from the response.
 *
 * Endpoint: chat.bsky.moderation.getConvos
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.getConvos(
parameters: ChatBskyModerationGetConvosParameters): ATProtoResponse<ChatBskyModerationGetConvosOutput> {
    val endpoint = "chat.bsky.moderation.getConvos"

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
