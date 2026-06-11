// Lexicon: 1, ID: chat.bsky.group.disableJoinLink
// [NOTE: This is under active development and should be considered unstable while this note is here]. Disables the active join link for the group convo.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupDisableJoinLinkDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.disableJoinLink"
}

@Serializable
    data class ChatBskyGroupDisableJoinLinkInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyGroupDisableJoinLinkOutput(
        @SerialName("joinLink")
        val joinLink: ChatBskyGroupDefsJoinLinkView    )

sealed class ChatBskyGroupDisableJoinLinkError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyGroupDisableJoinLinkError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupDisableJoinLinkError("InsufficientRole", "")
        object NoJoinLink: ChatBskyGroupDisableJoinLinkError("NoJoinLink", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Disables the active join link for the group convo.
 *
 * Endpoint: chat.bsky.group.disableJoinLink
 */
suspend fun ATProtoClient.Chat.Bsky.Group.disableJoinLink(
input: ChatBskyGroupDisableJoinLinkInput): ATProtoResponse<ChatBskyGroupDisableJoinLinkOutput> {
    val endpoint = "chat.bsky.group.disableJoinLink"

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
