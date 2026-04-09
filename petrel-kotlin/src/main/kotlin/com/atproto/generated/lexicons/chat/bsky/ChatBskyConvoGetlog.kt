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

@Serializable(with = ChatBskyConvoGetLogOutputLogsUnionSerializer::class)
sealed interface ChatBskyConvoGetLogOutputLogsUnion {
    @Serializable
    data class LogBeginConvo(val value: com.atproto.generated.ChatBskyConvoDefsLogBeginConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogAcceptConvo(val value: com.atproto.generated.ChatBskyConvoDefsLogAcceptConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogLeaveConvo(val value: com.atproto.generated.ChatBskyConvoDefsLogLeaveConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogMuteConvo(val value: com.atproto.generated.ChatBskyConvoDefsLogMuteConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogUnmuteConvo(val value: com.atproto.generated.ChatBskyConvoDefsLogUnmuteConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogCreateMessage(val value: com.atproto.generated.ChatBskyConvoDefsLogCreateMessage) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogDeleteMessage(val value: com.atproto.generated.ChatBskyConvoDefsLogDeleteMessage) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogReadMessage(val value: com.atproto.generated.ChatBskyConvoDefsLogReadMessage) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogAddReaction(val value: com.atproto.generated.ChatBskyConvoDefsLogAddReaction) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogRemoveReaction(val value: com.atproto.generated.ChatBskyConvoDefsLogRemoveReaction) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoGetLogOutputLogsUnion
}

object ChatBskyConvoGetLogOutputLogsUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoGetLogOutputLogsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoGetLogOutputLogsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoGetLogOutputLogsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoGetLogOutputLogsUnion.LogBeginConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogBeginConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logBeginConvo")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogAcceptConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogAcceptConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logAcceptConvo")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogLeaveConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogLeaveConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logLeaveConvo")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogMuteConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogMuteConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logMuteConvo")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogUnmuteConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogUnmuteConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logUnmuteConvo")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogCreateMessage -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogCreateMessage.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logCreateMessage")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogDeleteMessage -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogDeleteMessage.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logDeleteMessage")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogReadMessage -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogReadMessage.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logReadMessage")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogAddReaction -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogAddReaction.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logAddReaction")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogRemoveReaction -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogRemoveReaction.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logRemoveReaction")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoGetLogOutputLogsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#logBeginConvo" -> ChatBskyConvoGetLogOutputLogsUnion.LogBeginConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogBeginConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#logAcceptConvo" -> ChatBskyConvoGetLogOutputLogsUnion.LogAcceptConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogAcceptConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#logLeaveConvo" -> ChatBskyConvoGetLogOutputLogsUnion.LogLeaveConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogLeaveConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#logMuteConvo" -> ChatBskyConvoGetLogOutputLogsUnion.LogMuteConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogMuteConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#logUnmuteConvo" -> ChatBskyConvoGetLogOutputLogsUnion.LogUnmuteConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogUnmuteConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#logCreateMessage" -> ChatBskyConvoGetLogOutputLogsUnion.LogCreateMessage(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogCreateMessage.serializer(), element)
            )
            "chat.bsky.convo.defs#logDeleteMessage" -> ChatBskyConvoGetLogOutputLogsUnion.LogDeleteMessage(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogDeleteMessage.serializer(), element)
            )
            "chat.bsky.convo.defs#logReadMessage" -> ChatBskyConvoGetLogOutputLogsUnion.LogReadMessage(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogReadMessage.serializer(), element)
            )
            "chat.bsky.convo.defs#logAddReaction" -> ChatBskyConvoGetLogOutputLogsUnion.LogAddReaction(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogAddReaction.serializer(), element)
            )
            "chat.bsky.convo.defs#logRemoveReaction" -> ChatBskyConvoGetLogOutputLogsUnion.LogRemoveReaction(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogRemoveReaction.serializer(), element)
            )
            else -> ChatBskyConvoGetLogOutputLogsUnion.Unexpected(element)
        }
    }
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
