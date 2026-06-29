// Lexicon: 1, ID: chat.bsky.group.createJoinLink
// Creates a join link for the group convo.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupCreateJoinLinkDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.createJoinLink"
}

@Serializable
    data class ChatBskyGroupCreateJoinLinkInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("requireApproval")
        val requireApproval: Boolean? = null,        @SerialName("joinRule")
        val joinRule: ChatBskyGroupDefsJoinRule    )

    @Serializable
    data class ChatBskyGroupCreateJoinLinkOutput(
        @SerialName("joinLink")
        val joinLink: ChatBskyGroupDefsJoinLinkView    )

sealed class ChatBskyGroupCreateJoinLinkError(val name: String, val description: String?) {
        object EnabledJoinLinkAlreadyExists: ChatBskyGroupCreateJoinLinkError("EnabledJoinLinkAlreadyExists", "")
        object InvalidConvo: ChatBskyGroupCreateJoinLinkError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupCreateJoinLinkError("InsufficientRole", "")
    }

/**
 * Creates a join link for the group convo.
 *
 * Endpoint: chat.bsky.group.createJoinLink
 */
suspend fun ATProtoClient.Chat.Bsky.Group.createJoinLink(
input: ChatBskyGroupCreateJoinLinkInput): ATProtoResponse<ChatBskyGroupCreateJoinLinkOutput> {
    val endpoint = "chat.bsky.group.createJoinLink"

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
