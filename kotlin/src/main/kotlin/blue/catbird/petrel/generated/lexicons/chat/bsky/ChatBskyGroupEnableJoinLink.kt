// Lexicon: 1, ID: chat.bsky.group.enableJoinLink
// [NOTE: This is under active development and should be considered unstable while this note is here]. Re-enables a previously disabled join link for the group convo.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupEnableJoinLinkDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.enableJoinLink"
}

@Serializable
    data class ChatBskyGroupEnableJoinLinkInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyGroupEnableJoinLinkOutput(
        @SerialName("joinLink")
        val joinLink: ChatBskyGroupDefsJoinLinkView    )

sealed class ChatBskyGroupEnableJoinLinkError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyGroupEnableJoinLinkError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupEnableJoinLinkError("InsufficientRole", "")
        object NoJoinLink: ChatBskyGroupEnableJoinLinkError("NoJoinLink", "")
        object LinkAlreadyEnabled: ChatBskyGroupEnableJoinLinkError("LinkAlreadyEnabled", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Re-enables a previously disabled join link for the group convo.
 *
 * Endpoint: chat.bsky.group.enableJoinLink
 */
suspend fun ATProtoClient.Chat.Bsky.Group.enableJoinLink(
input: ChatBskyGroupEnableJoinLinkInput): ATProtoResponse<ChatBskyGroupEnableJoinLinkOutput> {
    val endpoint = "chat.bsky.group.enableJoinLink"

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
