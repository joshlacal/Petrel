// Lexicon: 1, ID: chat.bsky.group.editJoinLink
// [NOTE: This is under active development and should be considered unstable while this note is here]. Edits the existing join link settings for the group convo.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupEditJoinLinkDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.editJoinLink"
}

@Serializable
    data class ChatBskyGroupEditJoinLinkInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("requireApproval")
        val requireApproval: Boolean? = null,        @SerialName("joinRule")
        val joinRule: ChatBskyGroupDefsJoinRule? = null    )

    @Serializable
    data class ChatBskyGroupEditJoinLinkOutput(
        @SerialName("joinLink")
        val joinLink: ChatBskyGroupDefsJoinLinkView    )

sealed class ChatBskyGroupEditJoinLinkError(val name: String, val description: String?) {
        object InvalidConvo: ChatBskyGroupEditJoinLinkError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupEditJoinLinkError("InsufficientRole", "")
        object NoJoinLink: ChatBskyGroupEditJoinLinkError("NoJoinLink", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Edits the existing join link settings for the group convo.
 *
 * Endpoint: chat.bsky.group.editJoinLink
 */
suspend fun ATProtoClient.Chat.Bsky.Group.editJoinLink(
input: ChatBskyGroupEditJoinLinkInput): ATProtoResponse<ChatBskyGroupEditJoinLinkOutput> {
    val endpoint = "chat.bsky.group.editJoinLink"

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
