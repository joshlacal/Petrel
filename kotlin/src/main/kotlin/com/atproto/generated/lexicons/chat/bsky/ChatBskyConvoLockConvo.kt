// Lexicon: 1, ID: chat.bsky.convo.lockConvo
// [NOTE: This is under active development and should be considered unstable while this note is here]. Locks a group convo so no more content (messages, reactions) can be added to it.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoLockConvoDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.lockConvo"
}

@Serializable
    data class ChatBskyConvoLockConvoInput(
        @SerialName("convoId")
        val convoId: String    )

    @Serializable
    data class ChatBskyConvoLockConvoOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyConvoLockConvoError(val name: String, val description: String?) {
        object ConvoLocked: ChatBskyConvoLockConvoError("ConvoLocked", "")
        object InvalidConvo: ChatBskyConvoLockConvoError("InvalidConvo", "")
        object InsufficientRole: ChatBskyConvoLockConvoError("InsufficientRole", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Locks a group convo so no more content (messages, reactions) can be added to it.
 *
 * Endpoint: chat.bsky.convo.lockConvo
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.lockConvo(
input: ChatBskyConvoLockConvoInput): ATProtoResponse<ChatBskyConvoLockConvoOutput> {
    val endpoint = "chat.bsky.convo.lockConvo"

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
