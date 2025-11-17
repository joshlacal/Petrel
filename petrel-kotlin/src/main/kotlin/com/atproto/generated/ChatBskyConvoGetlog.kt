// Lexicon: 1, ID: chat.bsky.convo.getLog

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface OutputLogsUnion {
    @Serializable
    @SerialName("ChatBskyConvoDefs.Logbeginconvo")
    data class Logbeginconvo(val value: ChatBskyConvoDefs.Logbeginconvo) : OutputLogsUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Logacceptconvo")
    data class Logacceptconvo(val value: ChatBskyConvoDefs.Logacceptconvo) : OutputLogsUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Logleaveconvo")
    data class Logleaveconvo(val value: ChatBskyConvoDefs.Logleaveconvo) : OutputLogsUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Logmuteconvo")
    data class Logmuteconvo(val value: ChatBskyConvoDefs.Logmuteconvo) : OutputLogsUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Logunmuteconvo")
    data class Logunmuteconvo(val value: ChatBskyConvoDefs.Logunmuteconvo) : OutputLogsUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Logcreatemessage")
    data class Logcreatemessage(val value: ChatBskyConvoDefs.Logcreatemessage) : OutputLogsUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Logdeletemessage")
    data class Logdeletemessage(val value: ChatBskyConvoDefs.Logdeletemessage) : OutputLogsUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Logreadmessage")
    data class Logreadmessage(val value: ChatBskyConvoDefs.Logreadmessage) : OutputLogsUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Logaddreaction")
    data class Logaddreaction(val value: ChatBskyConvoDefs.Logaddreaction) : OutputLogsUnion

    @Serializable
    @SerialName("ChatBskyConvoDefs.Logremovereaction")
    data class Logremovereaction(val value: ChatBskyConvoDefs.Logremovereaction) : OutputLogsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : OutputLogsUnion
}

object ChatBskyConvoGetlog {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getLog"

    @Serializable
    data class Parameters(
        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("logs")
        val logs: List<OutputLogsUnion>    )

}

/**
 * 
 *
 * Endpoint: chat.bsky.convo.getLog
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getlog(
parameters: ChatBskyConvoGetlog.Parameters): ATProtoResponse<ChatBskyConvoGetlog.Output> {
    val endpoint = "chat.bsky.convo.getLog"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
