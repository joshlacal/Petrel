// Lexicon: 1, ID: chat.bsky.convo.getConvoForMembers

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetConvoForMembersDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getConvoForMembers"
}

@Serializable
    data class ChatBskyConvoGetConvoForMembersParameters(
        @SerialName("members")
        val members: List<DID>    )

    @Serializable
    data class ChatBskyConvoGetConvoForMembersOutput(
        @SerialName("convo")
        val convo: ChatBskyConvoDefsConvoView    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.getConvoForMembers
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getConvoForMembers(
parameters: ChatBskyConvoGetConvoForMembersParameters): ATProtoResponse<ChatBskyConvoGetConvoForMembersOutput> {
    val endpoint = "chat.bsky.convo.getConvoForMembers"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
