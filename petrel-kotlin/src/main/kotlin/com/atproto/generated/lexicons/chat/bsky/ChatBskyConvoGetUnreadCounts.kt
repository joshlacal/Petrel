// Lexicon: 1, ID: chat.bsky.convo.getUnreadCounts
// Returns unread conversation counts equivalent to one page of chat.bsky.convo.listConvos with readState=unread and lockStatus=unlocked, split by convo status. The combined total is capped at 31, where 31 means more than 30.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetUnreadCountsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getUnreadCounts"
}

    @Serializable
    data class ChatBskyConvoGetUnreadCountsOutput(
// Number of unread, unlocked accepted convos. Counts convos with unread messages and unread join requests. Capped at 31, where 31 means more than 30.        @SerialName("unreadAcceptedConvos")
        val unreadAcceptedConvos: Int,// Number of unread, unlocked request convos. Includes convos with unread messages, but not with unread join request, since only the owner of a group has join requests to read, and the group would necessarily be accepted. Capped at 11, where 11 means more than 10.        @SerialName("unreadRequestConvos")
        val unreadRequestConvos: Int    )

/**
 * Returns unread conversation counts equivalent to one page of chat.bsky.convo.listConvos with readState=unread and lockStatus=unlocked, split by convo status. The combined total is capped at 31, where 31 means more than 30.
 *
 * Endpoint: chat.bsky.convo.getUnreadCounts
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getUnreadCounts(
): ATProtoResponse<ChatBskyConvoGetUnreadCountsOutput> {
    val endpoint = "chat.bsky.convo.getUnreadCounts"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
