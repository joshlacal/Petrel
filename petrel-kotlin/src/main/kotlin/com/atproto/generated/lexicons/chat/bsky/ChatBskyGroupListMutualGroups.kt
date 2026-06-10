// Lexicon: 1, ID: chat.bsky.group.listMutualGroups
// [NOTE: This is under active development and should be considered unstable while this note is here]. Returns a page of group conversations that both the requester and the specified actor are members of.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupListMutualGroupsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.listMutualGroups"
}

@Serializable
    data class ChatBskyGroupListMutualGroupsParameters(
        @SerialName("subject")
        val subject: DID,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ChatBskyGroupListMutualGroupsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("convos")
        val convos: List<ChatBskyConvoDefsConvoView>    )

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Returns a page of group conversations that both the requester and the specified actor are members of.
 *
 * Endpoint: chat.bsky.group.listMutualGroups
 */
suspend fun ATProtoClient.Chat.Bsky.Group.listMutualGroups(
parameters: ChatBskyGroupListMutualGroupsParameters): ATProtoResponse<ChatBskyGroupListMutualGroupsOutput> {
    val endpoint = "chat.bsky.group.listMutualGroups"

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
