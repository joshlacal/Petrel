// Lexicon: 1, ID: chat.bsky.convo.unlockConvo
// [NOTE: This is under active development and should be considered unstable while this note is here]. Unlocks a group convo so it is able to receive new content.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoUnlockConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.unlockConvo"
}

@Serializable
    data class ChatBskyConvoUnlockConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoUnlockConvoOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyConvoUnlockConvoError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoUnlockConvoError("InvalidConvo", "")
        object InsufficientRole: ChatBskyConvoUnlockConvoError("InsufficientRole", "")
        object ConvoLockedByModeration: ChatBskyConvoUnlockConvoError("ConvoLockedByModeration", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Unlocks a group convo so it is able to receive new content.
 *
 * Endpoint: chat.bsky.convo.unlockConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.unlockConvo(
input: ChatBskyConvoUnlockConvoInput): ATProtoResponse<ChatBskyConvoUnlockConvoOutput> {
    val endpoint = "chat.bsky.convo.unlockConvo"

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
