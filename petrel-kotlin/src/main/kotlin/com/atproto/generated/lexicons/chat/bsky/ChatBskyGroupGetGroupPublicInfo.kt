// Lexicon: 1, ID: chat.bsky.group.getGroupPublicInfo
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

object ChatBskyGroupGetGroupPublicInfoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.getGroupPublicInfo"
}

@Serializable
    data class ChatBskyGroupGetGroupPublicInfoParameters(
        @SerialName("code")
        val code: String    )

    @Serializable
    data class ChatBskyGroupGetGroupPublicInfoOutput(
        @SerialName("group")
        val group: ChatBskyGroupDefsGroupPublicView    )

sealed class ChatBskyGroupGetGroupPublicInfoError(val name: String, val description: String?) {
        object InvalidCode: ChatBskyGroupGetGroupPublicInfoError("InvalidCode", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Get public information about a group from an join link.
 *
 * Endpoint: chat.bsky.group.getGroupPublicInfo
 */
suspend fun ATProtoClient.Chat.Bsky.Group.getGroupPublicInfo(
parameters: ChatBskyGroupGetGroupPublicInfoParameters): ATProtoResponse<ChatBskyGroupGetGroupPublicInfoOutput> {
    val endpoint = "chat.bsky.group.getGroupPublicInfo"

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
