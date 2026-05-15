// Lexicon: 1, ID: chat.bsky.convo.getLog

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
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
    data class LogReadConvo(val value: com.atproto.generated.ChatBskyConvoDefsLogReadConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogAddMember(val value: com.atproto.generated.ChatBskyConvoDefsLogAddMember) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogRemoveMember(val value: com.atproto.generated.ChatBskyConvoDefsLogRemoveMember) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogMemberJoin(val value: com.atproto.generated.ChatBskyConvoDefsLogMemberJoin) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogMemberLeave(val value: com.atproto.generated.ChatBskyConvoDefsLogMemberLeave) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogLockConvo(val value: com.atproto.generated.ChatBskyConvoDefsLogLockConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogUnlockConvo(val value: com.atproto.generated.ChatBskyConvoDefsLogUnlockConvo) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogLockConvoPermanently(val value: com.atproto.generated.ChatBskyConvoDefsLogLockConvoPermanently) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogEditGroup(val value: com.atproto.generated.ChatBskyConvoDefsLogEditGroup) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogCreateJoinLink(val value: com.atproto.generated.ChatBskyConvoDefsLogCreateJoinLink) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogEditJoinLink(val value: com.atproto.generated.ChatBskyConvoDefsLogEditJoinLink) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogEnableJoinLink(val value: com.atproto.generated.ChatBskyConvoDefsLogEnableJoinLink) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogDisableJoinLink(val value: com.atproto.generated.ChatBskyConvoDefsLogDisableJoinLink) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogIncomingJoinRequest(val value: com.atproto.generated.ChatBskyConvoDefsLogIncomingJoinRequest) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogApproveJoinRequest(val value: com.atproto.generated.ChatBskyConvoDefsLogApproveJoinRequest) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogRejectJoinRequest(val value: com.atproto.generated.ChatBskyConvoDefsLogRejectJoinRequest) : ChatBskyConvoGetLogOutputLogsUnion

    @Serializable
    data class LogOutgoingJoinRequest(val value: com.atproto.generated.ChatBskyConvoDefsLogOutgoingJoinRequest) : ChatBskyConvoGetLogOutputLogsUnion

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
            is ChatBskyConvoGetLogOutputLogsUnion.LogReadConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogReadConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logReadConvo")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogAddMember -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogAddMember.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logAddMember")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogRemoveMember -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogRemoveMember.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logRemoveMember")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogMemberJoin -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogMemberJoin.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logMemberJoin")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogMemberLeave -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogMemberLeave.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logMemberLeave")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogLockConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogLockConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logLockConvo")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogUnlockConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogUnlockConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logUnlockConvo")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogLockConvoPermanently -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogLockConvoPermanently.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logLockConvoPermanently")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogEditGroup -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogEditGroup.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logEditGroup")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogCreateJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogCreateJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logCreateJoinLink")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogEditJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogEditJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logEditJoinLink")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogEnableJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogEnableJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logEnableJoinLink")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogDisableJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogDisableJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logDisableJoinLink")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogIncomingJoinRequest -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogIncomingJoinRequest.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logIncomingJoinRequest")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogApproveJoinRequest -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogApproveJoinRequest.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logApproveJoinRequest")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogRejectJoinRequest -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogRejectJoinRequest.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logRejectJoinRequest")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.LogOutgoingJoinRequest -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsLogOutgoingJoinRequest.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#logOutgoingJoinRequest")
                })
            }
            is ChatBskyConvoGetLogOutputLogsUnion.Unexpected -> value.value
            // Synthetic variants (e.g. <Union>Error / <Union>Unexpected added by
            // subscription codegen) are runtime-only sentinels; JSON round-trip
            // serialises them as an empty object tagged with the variant class
            // name. Consumers should filter these before JSON serialisation.
            else -> kotlinx.serialization.json.buildJsonObject {
                put("\$type", kotlinx.serialization.json.JsonPrimitive(value::class.simpleName ?: "Unknown"))
            }
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
            "chat.bsky.convo.defs#logReadConvo" -> ChatBskyConvoGetLogOutputLogsUnion.LogReadConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogReadConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#logAddMember" -> ChatBskyConvoGetLogOutputLogsUnion.LogAddMember(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogAddMember.serializer(), element)
            )
            "chat.bsky.convo.defs#logRemoveMember" -> ChatBskyConvoGetLogOutputLogsUnion.LogRemoveMember(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogRemoveMember.serializer(), element)
            )
            "chat.bsky.convo.defs#logMemberJoin" -> ChatBskyConvoGetLogOutputLogsUnion.LogMemberJoin(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogMemberJoin.serializer(), element)
            )
            "chat.bsky.convo.defs#logMemberLeave" -> ChatBskyConvoGetLogOutputLogsUnion.LogMemberLeave(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogMemberLeave.serializer(), element)
            )
            "chat.bsky.convo.defs#logLockConvo" -> ChatBskyConvoGetLogOutputLogsUnion.LogLockConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogLockConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#logUnlockConvo" -> ChatBskyConvoGetLogOutputLogsUnion.LogUnlockConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogUnlockConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#logLockConvoPermanently" -> ChatBskyConvoGetLogOutputLogsUnion.LogLockConvoPermanently(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogLockConvoPermanently.serializer(), element)
            )
            "chat.bsky.convo.defs#logEditGroup" -> ChatBskyConvoGetLogOutputLogsUnion.LogEditGroup(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogEditGroup.serializer(), element)
            )
            "chat.bsky.convo.defs#logCreateJoinLink" -> ChatBskyConvoGetLogOutputLogsUnion.LogCreateJoinLink(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogCreateJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#logEditJoinLink" -> ChatBskyConvoGetLogOutputLogsUnion.LogEditJoinLink(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogEditJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#logEnableJoinLink" -> ChatBskyConvoGetLogOutputLogsUnion.LogEnableJoinLink(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogEnableJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#logDisableJoinLink" -> ChatBskyConvoGetLogOutputLogsUnion.LogDisableJoinLink(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogDisableJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#logIncomingJoinRequest" -> ChatBskyConvoGetLogOutputLogsUnion.LogIncomingJoinRequest(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogIncomingJoinRequest.serializer(), element)
            )
            "chat.bsky.convo.defs#logApproveJoinRequest" -> ChatBskyConvoGetLogOutputLogsUnion.LogApproveJoinRequest(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogApproveJoinRequest.serializer(), element)
            )
            "chat.bsky.convo.defs#logRejectJoinRequest" -> ChatBskyConvoGetLogOutputLogsUnion.LogRejectJoinRequest(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogRejectJoinRequest.serializer(), element)
            )
            "chat.bsky.convo.defs#logOutgoingJoinRequest" -> ChatBskyConvoGetLogOutputLogsUnion.LogOutgoingJoinRequest(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsLogOutgoingJoinRequest.serializer(), element)
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

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
