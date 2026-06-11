// Lexicon: 1, ID: chat.bsky.group.removeMembers
// [NOTE: This is under active development and should be considered unstable while this note is here]. Removes members from a group. This deletes convo memberships, doesn't just set a status.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupRemoveMembersDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.removeMembers"
}

@Serializable
    data class ChatBskyGroupRemoveMembersInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("members")
        val members: List<DID>    )

    @Serializable
    data class ChatBskyGroupRemoveMembersOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyGroupRemoveMembersError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyGroupRemoveMembersError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupRemoveMembersError("InsufficientRole", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Removes members from a group. This deletes convo memberships, doesn't just set a status.
 *
 * Endpoint: chat.bsky.group.removeMembers
 */
suspend fun ATProtoClient.Chat.Bsky.Group.removeMembers(
input: ChatBskyGroupRemoveMembersInput): ATProtoResponse<ChatBskyGroupRemoveMembersOutput> {
    val endpoint = "chat.bsky.group.removeMembers"

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
