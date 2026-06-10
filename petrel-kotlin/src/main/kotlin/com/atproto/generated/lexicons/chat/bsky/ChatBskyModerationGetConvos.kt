// Lexicon: 1, ID: chat.bsky.moderation.getConvos
// [NOTE: This is under active development and should be considered unstable while this note is here]. Gets existing conversations by their IDs, for moderation purposes. Does not require the requester to be a member of the conversations. Unknown IDs are silently omitted from the response.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
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
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Gets existing conversations by their IDs, for moderation purposes. Does not require the requester to be a member of the conversations. Unknown IDs are silently omitted from the response.
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
