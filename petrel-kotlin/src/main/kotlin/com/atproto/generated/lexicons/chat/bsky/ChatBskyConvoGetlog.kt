// Lexicon: 1, ID: chat.bsky.convo.getLog

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetLogDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getLog"
}

@Serializable
sealed interface ChatBskyConvoGetLogOutputLogsUnion {
    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogBeginConvo")
    data class ChatBskyConvoDefsLogBeginConvo(val value: ChatBskyConvoDefsLogBeginConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogAcceptConvo")
    data class ChatBskyConvoDefsLogAcceptConvo(val value: ChatBskyConvoDefsLogAcceptConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogLeaveConvo")
    data class ChatBskyConvoDefsLogLeaveConvo(val value: ChatBskyConvoDefsLogLeaveConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogMuteConvo")
    data class ChatBskyConvoDefsLogMuteConvo(val value: ChatBskyConvoDefsLogMuteConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogUnmuteConvo")
    data class ChatBskyConvoDefsLogUnmuteConvo(val value: ChatBskyConvoDefsLogUnmuteConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogCreateMessage")
    data class ChatBskyConvoDefsLogCreateMessage(val value: ChatBskyConvoDefsLogCreateMessage) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogDeleteMessage")
    data class ChatBskyConvoDefsLogDeleteMessage(val value: ChatBskyConvoDefsLogDeleteMessage) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogReadMessage")
    data class ChatBskyConvoDefsLogReadMessage(val value: ChatBskyConvoDefsLogReadMessage) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogAddReaction")
    data class ChatBskyConvoDefsLogAddReaction(val value: ChatBskyConvoDefsLogAddReaction) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("chat.bsky.convo.getLog#ChatBskyConvoDefsLogRemoveReaction")
    data class ChatBskyConvoDefsLogRemoveReaction(val value: ChatBskyConvoDefsLogRemoveReaction) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ChatBskyConvoGetLogOutputLogsUnion
}

@Serializable
    data class ChatBskyConvoGetLogParameters(
        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ChatBskyConvoGetLogOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("logs")
        val logs: List<ChatBskyConvoGetLogOutputLogsUnion>    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.getLog
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getLog(
parameters: ChatBskyConvoGetLogParameters): ATProtoResponse<ChatBskyConvoGetLogOutput> {
    val endpoint = "chat.bsky.convo.getLog"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
