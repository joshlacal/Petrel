// Lexicon: 1, ID: chat.bsky.group.withdrawJoinRequest
// [NOTE: This is under active development and should be considered unstable while this note is here]. Withdraws a pending request to join a group. Action taken by the prospective member who originally requested to join.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupWithdrawJoinRequestDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.withdrawJoinRequest"
}

@Serializable
    data class ChatBskyGroupWithdrawJoinRequestInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    class ChatBskyGroupWithdrawJoinRequestOutput

sealed class ChatBskyGroupWithdrawJoinRequestError(val name: String, val description: String?) {
        object InvalidJoinRequest: ChatBskyGroupWithdrawJoinRequestError("InvalidJoinRequest", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Withdraws a pending request to join a group. Action taken by the prospective member who originally requested to join.
 *
 * Endpoint: chat.bsky.group.withdrawJoinRequest
 */
suspend fun ATProtoClient.Chat.Bsky.Group.withdrawJoinRequest(
input: ChatBskyGroupWithdrawJoinRequestInput): ATProtoResponse<ChatBskyGroupWithdrawJoinRequestOutput> {
    val endpoint = "chat.bsky.group.withdrawJoinRequest"

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
