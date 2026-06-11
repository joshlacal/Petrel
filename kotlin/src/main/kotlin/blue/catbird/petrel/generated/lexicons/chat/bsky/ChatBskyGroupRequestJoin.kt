// Lexicon: 1, ID: chat.bsky.group.requestJoin
// [NOTE: This is under active development and should be considered unstable while this note is here]. Sends a request to join a group (via join link) to the group owner. Action taken by the prospective group member.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupRequestJoinDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.requestJoin"
}

@Serializable
    data class ChatBskyGroupRequestJoinInput(
        @SerialName("code")
        val code: String    )

    @Serializable
    data class ChatBskyGroupRequestJoinOutput(
        @SerialName("status")
        val status: String,// The group convo joined. This is only present in the case of status=joined        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView? = null    )

sealed class ChatBskyGroupRequestJoinError(val name: String, val description: String?) {
        object ConvoLocked: ChatBskyGroupRequestJoinError("ConvoLocked", "")
        object FollowRequired: ChatBskyGroupRequestJoinError("FollowRequired", "")
        object InvalidCode: ChatBskyGroupRequestJoinError("InvalidCode", "")
        object LinkDisabled: ChatBskyGroupRequestJoinError("LinkDisabled", "")
        object MemberLimitReached: ChatBskyGroupRequestJoinError("MemberLimitReached", "")
        object UserKicked: ChatBskyGroupRequestJoinError("UserKicked", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Sends a request to join a group (via join link) to the group owner. Action taken by the prospective group member.
 *
 * Endpoint: chat.bsky.group.requestJoin
 */
suspend fun ATProtoClient.Chat.Bsky.Group.requestJoin(
input: ChatBskyGroupRequestJoinInput): ATProtoResponse<ChatBskyGroupRequestJoinOutput> {
    val endpoint = "chat.bsky.group.requestJoin"

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
