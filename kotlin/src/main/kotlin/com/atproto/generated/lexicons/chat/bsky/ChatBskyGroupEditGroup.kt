// Lexicon: 1, ID: chat.bsky.group.editGroup
// [NOTE: This is under active development and should be considered unstable while this note is here]. Edits group settings.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupEditGroupDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.editGroup"
}

@Serializable
    data class ChatBskyGroupEditGroupInput(
        @SerialName("convoId")
        val convoId: String,        @SerialName("name")
        val name: String    )

    @Serializable
    data class ChatBskyGroupEditGroupOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

sealed class ChatBskyGroupEditGroupError(val name: String, val description: String?) {
        object ConvoLocked: ChatBskyGroupEditGroupError("ConvoLocked", "")
        object InvalidConvo: ChatBskyGroupEditGroupError("InvalidConvo", "")
        object InsufficientRole: ChatBskyGroupEditGroupError("InsufficientRole", "")
    }

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Edits group settings.
 *
 * Endpoint: chat.bsky.group.editGroup
 */
suspend fun ATProtoClient.Chat.Bsky.Group.editGroup(
input: ChatBskyGroupEditGroupInput): ATProtoResponse<ChatBskyGroupEditGroupOutput> {
    val endpoint = "chat.bsky.group.editGroup"

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
