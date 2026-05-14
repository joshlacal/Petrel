// Lexicon: 1, ID: chat.bsky.convo.deleteMessageForSelf
// Marks a message as deleted for the viewer, so they won't see that message in future enumerations.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoDeleteMessageForSelfDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.deleteMessageForSelf"
}

@Serializable
    data class ChatBskyConvoDeleteMessageForSelfInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String    )

    typealias ChatBskyConvoDeleteMessageForSelfOutput = ChatBskyConvoDefsDeletedMessageView

sealed class ChatBskyConvoDeleteMessageForSelfError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyConvoDeleteMessageForSelfError("InvalidConvo", "")
        object MessageDeleteNotAllowed: ChatBskyConvoDeleteMessageForSelfError("MessageDeleteNotAllowed", "Indicates that this message cannot be deleted, e.g. because it is a system message.")
    }

/**
 * Marks a message as deleted for the viewer, so they won't see that message in future enumerations.
 *
 * Endpoint: chat.bsky.convo.deleteMessageForSelf
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.deleteMessageForSelf(
input: ChatBskyConvoDeleteMessageForSelfInput): ATProtoResponse<ChatBskyConvoDeleteMessageForSelfOutput> {
    val endpoint = "chat.bsky.convo.deleteMessageForSelf"

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
