// Lexicon: 1, ID: chat.bsky.group.listJoinRequests
// [NOTE: This is under active development and should be considered unstable while this note is here]. Lists a page of request to join a group (via join link) the user owns. Shows the data from the owner's point of view.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupListJoinRequestsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.listJoinRequests"
}

@Serializable
    data class ChatBskyGroupListJoinRequestsParameters(
        @SerialName("convoId")
        val convoId: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ChatBskyGroupListJoinRequestsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("requests")
        val requests: List<ChatBskyGroupDefsJoinRequestView>    )

sealed class ChatBskyGroupListJoinRequestsError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyGroupListJoinRequestsError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupListJoinRequestsError("InsufficientRole", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Lists a page of request to join a group (via join link) the user owns. Shows the data from the owner's point of view.
 *
 * Endpoint: chat.bsky.group.listJoinRequests
 */
suspend fun ATProtoClient.Chat.Bsky.Group.listJoinRequests(
parameters: ChatBskyGroupListJoinRequestsParameters): ATProtoResponse<ChatBskyGroupListJoinRequestsOutput> {
    val endpoint = "chat.bsky.group.listJoinRequests"

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
