// Lexicon: 1, ID: chat.bsky.convo.leaveConvo
// Leaves a conversation (direct or group). For group, this effectively removes membership. For direct, membership is never removed, only changed to remove from enumerations by the user who left.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoLeaveConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.leaveConvo"
}

@Serializable
    data class ChatBskyConvoLeaveConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoLeaveConvoOutput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("rev")
        val rev: String    )

sealed class ChatBskyConvoLeaveConvoError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoLeaveConvoError("InvalidConvo", "")
        object OwnerCannotLeave: ChatBskyConvoLeaveConvoError("OwnerCannotLeave", "The owner of a group conversation cannot leave before locking the group.")
    }

/**
 * Leaves a conversation (direct or group). For group, this effectively removes membership. For direct, membership is never removed, only changed to remove from enumerations by the user who left.
 *
 * Endpoint: chat.bsky.convo.leaveConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.leaveConvo(
input: ChatBskyConvoLeaveConvoInput): ATProtoResponse<ChatBskyConvoLeaveConvoOutput> {
    val endpoint = "chat.bsky.convo.leaveConvo"

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
