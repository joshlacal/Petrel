// Lexicon: 1, ID: chat.bsky.group.getJoinLinkPreview
// [NOTE: This is under active development and should be considered unstable while this note is here]. Get public information about a group from an join link.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupGetJoinLinkPreviewDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.getJoinLinkPreview"
}

@Serializable
    data class ChatBskyGroupGetJoinLinkPreviewParameters(
        @SerialName("code")
        val code: String    )

    @Serializable
    data class ChatBskyGroupGetJoinLinkPreviewOutput(
        @SerialName("joinLinkPreview")
        val joinLinkPreview: ChatBskyGroupDefsJoinLinkPreviewView    )

sealed class ChatBskyGroupGetJoinLinkPreviewError(val name: String, val description: String?) {
        object InvalidCode: ChatBskyGroupGetJoinLinkPreviewError("InvalidCode", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Get public information about a group from an join link.
 *
 * Endpoint: chat.bsky.group.getJoinLinkPreview
 */
suspend fun ATProtoClient.Chat.Bsky.Group.getJoinLinkPreview(
parameters: ChatBskyGroupGetJoinLinkPreviewParameters): ATProtoResponse<ChatBskyGroupGetJoinLinkPreviewOutput> {
    val endpoint = "chat.bsky.group.getJoinLinkPreview"

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
