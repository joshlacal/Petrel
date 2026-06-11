// Lexicon: 1, ID: chat.bsky.group.createJoinLink
// [NOTE: This is under active development and should be considered unstable while this note is here]. Creates a join link for the group convo.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
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
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Creates a join link for the group convo.
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
