// Lexicon: 1, ID: chat.bsky.convo.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoDefsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.defs"
}

@Serializable(with = ChatBskyConvoDefsMessageInputEmbedUnionSerializer::class)
sealed interface ChatBskyConvoDefsMessageInputEmbedUnion {
    @Serializable
    data class Record(val value: com.atproto.generated.AppBskyEmbedRecord) : ChatBskyConvoDefsMessageInputEmbedUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsMessageInputEmbedUnion
}

object ChatBskyConvoDefsMessageInputEmbedUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsMessageInputEmbedUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsMessageInputEmbedUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsMessageInputEmbedUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsMessageInputEmbedUnion.Record -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecord.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record")
                })
            }
            is ChatBskyConvoDefsMessageInputEmbedUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsMessageInputEmbedUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.record" -> ChatBskyConvoDefsMessageInputEmbedUnion.Record(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecord.serializer(), element)
            )
            else -> ChatBskyConvoDefsMessageInputEmbedUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsMessageViewEmbedUnionSerializer::class)
sealed interface ChatBskyConvoDefsMessageViewEmbedUnion {
    @Serializable
    data class View(val value: com.atproto.generated.AppBskyEmbedRecordView) : ChatBskyConvoDefsMessageViewEmbedUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsMessageViewEmbedUnion
}

object ChatBskyConvoDefsMessageViewEmbedUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsMessageViewEmbedUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsMessageViewEmbedUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsMessageViewEmbedUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsMessageViewEmbedUnion.View -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#view")
                })
            }
            is ChatBskyConvoDefsMessageViewEmbedUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsMessageViewEmbedUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.record#view" -> ChatBskyConvoDefsMessageViewEmbedUnion.View(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordView.serializer(), element)
            )
            else -> ChatBskyConvoDefsMessageViewEmbedUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsSystemMessageViewDataUnionSerializer::class)
sealed interface ChatBskyConvoDefsSystemMessageViewDataUnion {
    @Serializable
    data class SystemMessageDataAddMember(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataAddMember) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataRemoveMember(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataRemoveMember) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataMemberJoin(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataMemberJoin) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataMemberLeave(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataMemberLeave) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataLockConvo(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataLockConvo) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataUnlockConvo(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataUnlockConvo) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataLockConvoPermanently(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataLockConvoPermanently) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataEditGroup(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataEditGroup) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataCreateJoinLink(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataCreateJoinLink) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataEditJoinLink(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataEditJoinLink) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataEnableJoinLink(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataEnableJoinLink) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataDisableJoinLink(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageDataDisableJoinLink) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsSystemMessageViewDataUnion
}

object ChatBskyConvoDefsSystemMessageViewDataUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsSystemMessageViewDataUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsSystemMessageViewDataUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsSystemMessageViewDataUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataAddMember -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataAddMember.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataAddMember")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataRemoveMember -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataRemoveMember.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataRemoveMember")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataMemberJoin -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataMemberJoin.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataMemberJoin")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataMemberLeave -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataMemberLeave.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataMemberLeave")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataLockConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataLockConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataLockConvo")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataUnlockConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataUnlockConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataUnlockConvo")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataLockConvoPermanently -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataLockConvoPermanently.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataLockConvoPermanently")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEditGroup -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataEditGroup.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataEditGroup")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataCreateJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataCreateJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataCreateJoinLink")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEditJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataEditJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataEditJoinLink")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEnableJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataEnableJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataEnableJoinLink")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataDisableJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataDisableJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataDisableJoinLink")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsSystemMessageViewDataUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#systemMessageDataAddMember" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataAddMember(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataAddMember.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataRemoveMember" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataRemoveMember(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataRemoveMember.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataMemberJoin" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataMemberJoin(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataMemberJoin.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataMemberLeave" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataMemberLeave(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataMemberLeave.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataLockConvo" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataLockConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataLockConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataUnlockConvo" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataUnlockConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataUnlockConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataLockConvoPermanently" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataLockConvoPermanently(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataLockConvoPermanently.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataEditGroup" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEditGroup(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataEditGroup.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataCreateJoinLink" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataCreateJoinLink(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataCreateJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataEditJoinLink" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEditJoinLink(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataEditJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataEnableJoinLink" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEnableJoinLink(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataEnableJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataDisableJoinLink" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataDisableJoinLink(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageDataDisableJoinLink.serializer(), element)
            )
            else -> ChatBskyConvoDefsSystemMessageViewDataUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsConvoViewLastMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsConvoViewLastMessageUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

    @Serializable
    data class SystemMessageView(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsConvoViewLastMessageUnion
}

object ChatBskyConvoDefsConvoViewLastMessageUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsConvoViewLastMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsConvoViewLastMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsConvoViewLastMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsConvoViewLastMessageUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsConvoViewLastMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsConvoViewLastMessageUnion.SystemMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageView")
                })
            }
            is ChatBskyConvoDefsConvoViewLastMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsConvoViewLastMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyConvoDefsConvoViewLastMessageUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsConvoViewLastMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageView" -> ChatBskyConvoDefsConvoViewLastMessageUnion.SystemMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsConvoViewLastMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsConvoViewLastReactionUnionSerializer::class)
sealed interface ChatBskyConvoDefsConvoViewLastReactionUnion {
    @Serializable
    data class MessageAndReactionView(val value: com.atproto.generated.ChatBskyConvoDefsMessageAndReactionView) : ChatBskyConvoDefsConvoViewLastReactionUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsConvoViewLastReactionUnion
}

object ChatBskyConvoDefsConvoViewLastReactionUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsConvoViewLastReactionUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsConvoViewLastReactionUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsConvoViewLastReactionUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsConvoViewLastReactionUnion.MessageAndReactionView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageAndReactionView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageAndReactionView")
                })
            }
            is ChatBskyConvoDefsConvoViewLastReactionUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsConvoViewLastReactionUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageAndReactionView" -> ChatBskyConvoDefsConvoViewLastReactionUnion.MessageAndReactionView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageAndReactionView.serializer(), element)
            )
            else -> ChatBskyConvoDefsConvoViewLastReactionUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsConvoViewKindUnionSerializer::class)
sealed interface ChatBskyConvoDefsConvoViewKindUnion {
    @Serializable
    data class DirectConvo(val value: com.atproto.generated.ChatBskyConvoDefsDirectConvo) : ChatBskyConvoDefsConvoViewKindUnion

    @Serializable
    data class GroupConvo(val value: com.atproto.generated.ChatBskyConvoDefsGroupConvo) : ChatBskyConvoDefsConvoViewKindUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsConvoViewKindUnion
}

object ChatBskyConvoDefsConvoViewKindUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsConvoViewKindUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsConvoViewKindUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsConvoViewKindUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsConvoViewKindUnion.DirectConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDirectConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#directConvo")
                })
            }
            is ChatBskyConvoDefsConvoViewKindUnion.GroupConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsGroupConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#groupConvo")
                })
            }
            is ChatBskyConvoDefsConvoViewKindUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsConvoViewKindUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#directConvo" -> ChatBskyConvoDefsConvoViewKindUnion.DirectConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDirectConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#groupConvo" -> ChatBskyConvoDefsConvoViewKindUnion.GroupConvo(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsGroupConvo.serializer(), element)
            )
            else -> ChatBskyConvoDefsConvoViewKindUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogCreateMessageMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogCreateMessageMessageUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogCreateMessageMessageUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogCreateMessageMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogCreateMessageMessageUnion
}

object ChatBskyConvoDefsLogCreateMessageMessageUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsLogCreateMessageMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsLogCreateMessageMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsLogCreateMessageMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsLogCreateMessageMessageUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogCreateMessageMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsLogCreateMessageMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsLogCreateMessageMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyConvoDefsLogCreateMessageMessageUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogCreateMessageMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogCreateMessageMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogDeleteMessageMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogDeleteMessageMessageUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogDeleteMessageMessageUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogDeleteMessageMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogDeleteMessageMessageUnion
}

object ChatBskyConvoDefsLogDeleteMessageMessageUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsLogDeleteMessageMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsLogDeleteMessageMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsLogDeleteMessageMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsLogDeleteMessageMessageUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogDeleteMessageMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsLogDeleteMessageMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsLogDeleteMessageMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyConvoDefsLogDeleteMessageMessageUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogDeleteMessageMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogDeleteMessageMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogReadMessageMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogReadMessageMessageUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogReadMessageMessageUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogReadMessageMessageUnion

    @Serializable
    data class SystemMessageView(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageView) : ChatBskyConvoDefsLogReadMessageMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogReadMessageMessageUnion
}

object ChatBskyConvoDefsLogReadMessageMessageUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsLogReadMessageMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsLogReadMessageMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsLogReadMessageMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsLogReadMessageMessageUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogReadMessageMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsLogReadMessageMessageUnion.SystemMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageView")
                })
            }
            is ChatBskyConvoDefsLogReadMessageMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsLogReadMessageMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyConvoDefsLogReadMessageMessageUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogReadMessageMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageView" -> ChatBskyConvoDefsLogReadMessageMessageUnion.SystemMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogReadMessageMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogAddReactionMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogAddReactionMessageUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogAddReactionMessageUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogAddReactionMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogAddReactionMessageUnion
}

object ChatBskyConvoDefsLogAddReactionMessageUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsLogAddReactionMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsLogAddReactionMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsLogAddReactionMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsLogAddReactionMessageUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogAddReactionMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsLogAddReactionMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsLogAddReactionMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyConvoDefsLogAddReactionMessageUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogAddReactionMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogAddReactionMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogRemoveReactionMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogRemoveReactionMessageUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogRemoveReactionMessageUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogRemoveReactionMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogRemoveReactionMessageUnion
}

object ChatBskyConvoDefsLogRemoveReactionMessageUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsLogRemoveReactionMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsLogRemoveReactionMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsLogRemoveReactionMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsLogRemoveReactionMessageUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogRemoveReactionMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsLogRemoveReactionMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsLogRemoveReactionMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyConvoDefsLogRemoveReactionMessageUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogRemoveReactionMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogRemoveReactionMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogReadConvoMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogReadConvoMessageUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogReadConvoMessageUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogReadConvoMessageUnion

    @Serializable
    data class SystemMessageView(val value: com.atproto.generated.ChatBskyConvoDefsSystemMessageView) : ChatBskyConvoDefsLogReadConvoMessageUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsLogReadConvoMessageUnion
}

object ChatBskyConvoDefsLogReadConvoMessageUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsLogReadConvoMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsLogReadConvoMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsLogReadConvoMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsLogReadConvoMessageUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogReadConvoMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsLogReadConvoMessageUnion.SystemMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageView")
                })
            }
            is ChatBskyConvoDefsLogReadConvoMessageUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsLogReadConvoMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyConvoDefsLogReadConvoMessageUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogReadConvoMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageView" -> ChatBskyConvoDefsLogReadConvoMessageUnion.SystemMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsSystemMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogReadConvoMessageUnion.Unexpected(element)
        }
    }
}

@Serializable
enum class ChatBskyConvoDefsConvoKind {
    @SerialName("direct")
    DIRECT,
    @SerialName("group")
    GROUP}

@Serializable
enum class ChatBskyConvoDefsConvoLockStatus {
    @SerialName("unlocked")
    UNLOCKED,
    @SerialName("locked")
    LOCKED,
    @SerialName("locked-permanently")
    LOCKED_PERMANENTLY}

@Serializable
enum class ChatBskyConvoDefsConvoStatus {
    @SerialName("request")
    REQUEST,
    @SerialName("accepted")
    ACCEPTED}

    @Serializable
    data class ChatBskyConvoDefsMessageRef(
        @SerialName("did")
        val did: DID,        @SerialName("convoId")
        val convoId: String,        @SerialName("messageId")
        val messageId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageRef"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsMessageInput(
        @SerialName("text")
        val text: String,/** Annotations of text (mentions, URLs, hashtags, etc) */        @SerialName("facets")
        val facets: List<AppBskyRichtextFacet>? = null,        @SerialName("embed")
        val embed: ChatBskyConvoDefsMessageInputEmbedUnion? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageInput"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsMessageView(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,        @SerialName("text")
        val text: String,/** Annotations of text (mentions, URLs, hashtags, etc) */        @SerialName("facets")
        val facets: List<AppBskyRichtextFacet>? = null,        @SerialName("embed")
        val embed: ChatBskyConvoDefsMessageViewEmbedUnion? = null,/** Reactions to this message, in ascending order of creation time. */        @SerialName("reactions")
        val reactions: List<ChatBskyConvoDefsReactionView>? = null,        @SerialName("sender")
        val sender: ChatBskyConvoDefsMessageViewSender,        @SerialName("sentAt")
        val sentAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsSystemMessageReferredUser(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageReferredUser"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here].
     */
    @Serializable
    data class ChatBskyConvoDefsSystemMessageView(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,        @SerialName("sentAt")
        val sentAt: ATProtocolDate,        @SerialName("data")
        val `data`: ChatBskyConvoDefsSystemMessageViewDataUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageView"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating a user was added to the group convo.
     */
    @Serializable
    data class ChatBskyConvoDefsSystemMessageDataAddMember(
/** Current view of the member who was added. */        @SerialName("member")
        val member: ChatBskyConvoDefsSystemMessageReferredUser,/** Role the user was added to the group with. The role from 'member' will reflect the current data, not historical. */        @SerialName("role")
        val role: ChatBskyActorDefsMemberRole,        @SerialName("addedBy")
        val addedBy: ChatBskyConvoDefsSystemMessageReferredUser    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataAddMember"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating a user was removed from the group convo.
     */
    @Serializable
    data class ChatBskyConvoDefsSystemMessageDataRemoveMember(
/** Current view of the member who was removed. */        @SerialName("member")
        val member: ChatBskyConvoDefsSystemMessageReferredUser,        @SerialName("removedBy")
        val removedBy: ChatBskyConvoDefsSystemMessageReferredUser    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataRemoveMember"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating a user joined the group convo via join link.
     */
    @Serializable
    data class ChatBskyConvoDefsSystemMessageDataMemberJoin(
/** Current view of the member who joined. */        @SerialName("member")
        val member: ChatBskyConvoDefsSystemMessageReferredUser,/** Role the user was added to the group with. The role from 'member' will reflect the current data, not historical. */        @SerialName("role")
        val role: ChatBskyActorDefsMemberRole,/** If join link was configured to require approval, this will be set to who approved the request. Undefined if approval was not required. */        @SerialName("approvedBy")
        val approvedBy: ChatBskyConvoDefsSystemMessageReferredUser? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataMemberJoin"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating a user voluntarily left the group convo.
     */
    @Serializable
    data class ChatBskyConvoDefsSystemMessageDataMemberLeave(
/** Current view of the member who left the group. */        @SerialName("member")
        val member: ChatBskyConvoDefsSystemMessageReferredUser    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataMemberLeave"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating the group convo was locked.
     */
    @Serializable
    data class ChatBskyConvoDefsSystemMessageDataLockConvo(
/** Current view of the member who locked the group. */        @SerialName("lockedBy")
        val lockedBy: ChatBskyConvoDefsSystemMessageReferredUser    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataLockConvo"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating the group convo was unlocked.
     */
    @Serializable
    data class ChatBskyConvoDefsSystemMessageDataUnlockConvo(
/** Current view of the member who unlocked the group. */        @SerialName("unlockedBy")
        val unlockedBy: ChatBskyConvoDefsSystemMessageReferredUser    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataUnlockConvo"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating the group convo was locked permanently.
     */
    @Serializable
    data class ChatBskyConvoDefsSystemMessageDataLockConvoPermanently(
/** Current view of the member who locked the group. */        @SerialName("lockedBy")
        val lockedBy: ChatBskyConvoDefsSystemMessageReferredUser    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataLockConvoPermanently"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating the group info was edited.
     */
    @Serializable
    data class ChatBskyConvoDefsSystemMessageDataEditGroup(
/** Group name that was replaced. */        @SerialName("oldName")
        val oldName: String? = null,/** Group name that replaced the old. */        @SerialName("newName")
        val newName: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataEditGroup"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating the group join link was created.
     */
    @Serializable
    class ChatBskyConvoDefsSystemMessageDataCreateJoinLink {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataCreateJoinLink"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating the group join link was edited.
     */
    @Serializable
    class ChatBskyConvoDefsSystemMessageDataEditJoinLink {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataEditJoinLink"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating the group join link was enabled.
     */
    @Serializable
    class ChatBskyConvoDefsSystemMessageDataEnableJoinLink {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataEnableJoinLink"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. System message indicating the group join link was disabled.
     */
    @Serializable
    class ChatBskyConvoDefsSystemMessageDataDisableJoinLink {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataDisableJoinLink"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsDeletedMessageView(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,        @SerialName("sender")
        val sender: ChatBskyConvoDefsMessageViewSender,        @SerialName("sentAt")
        val sentAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsDeletedMessageView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsMessageViewSender(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageViewSender"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsReactionView(
        @SerialName("value")
        val value: String,        @SerialName("sender")
        val sender: ChatBskyConvoDefsReactionViewSender,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsReactionView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsReactionViewSender(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsReactionViewSender"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsMessageAndReactionView(
        @SerialName("message")
        val message: ChatBskyConvoDefsMessageView,        @SerialName("reaction")
        val reaction: ChatBskyConvoDefsReactionView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageAndReactionView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsConvoView(
        @SerialName("id")
        val id: String,        @SerialName("rev")
        val rev: String,/** Members of this conversation. For direct convos, it will be an immutable list of the 2 members. For group convos, it will a list of important members (the first few members, the viewer, the member who invited the viewer, the member who sent the last message, the member who sent the last reaction), but will not contain the full list of members. Use chat.bsky.convo.getConvoMembers to list all members. */        @SerialName("members")
        val members: List<ChatBskyActorDefsProfileViewBasic>,        @SerialName("lastMessage")
        val lastMessage: ChatBskyConvoDefsConvoViewLastMessageUnion? = null,        @SerialName("lastReaction")
        val lastReaction: ChatBskyConvoDefsConvoViewLastReactionUnion? = null,        @SerialName("muted")
        val muted: Boolean,/** Convo status for the viewer member (not the convo itself). */        @SerialName("status")
        val status: ChatBskyConvoDefsConvoStatus? = null,        @SerialName("unreadCount")
        val unreadCount: Int,/** Union field that has data specific to different kinds of convos. */        @SerialName("kind")
        val kind: ChatBskyConvoDefsConvoViewKindUnion? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsConvoView"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here].
     */
    @Serializable
    class ChatBskyConvoDefsDirectConvo {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsDirectConvo"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here].
     */
    @Serializable
    data class ChatBskyConvoDefsGroupConvo(
/** The display name of the group conversation. */        @SerialName("name")
        val name: String,/** The total number of members in the group conversation. */        @SerialName("memberCount")
        val memberCount: Int,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("joinLink")
        val joinLink: ChatBskyGroupDefsJoinLinkView? = null,/** The lock status of the conversation. */        @SerialName("lockStatus")
        val lockStatus: ChatBskyConvoDefsConvoLockStatus    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsGroupConvo"
        }
    }

    /**
     * Event indicating a convo containing the viewer was started. Can be direct or group. When a member is added to a group convo, they also get this event.
     */
    @Serializable
    data class ChatBskyConvoDefsLogBeginConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogBeginConvo"
        }
    }

    /**
     * Event indicating the viewer accepted a convo, and it can be moved out of the request inbox. Can be direct or group.
     */
    @Serializable
    data class ChatBskyConvoDefsLogAcceptConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogAcceptConvo"
        }
    }

    /**
     * Event indicating the viewer left a convo. Can be direct or group.
     */
    @Serializable
    data class ChatBskyConvoDefsLogLeaveConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogLeaveConvo"
        }
    }

    /**
     * Event indicating the viewer muted a convo. Can be direct or group.
     */
    @Serializable
    data class ChatBskyConvoDefsLogMuteConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogMuteConvo"
        }
    }

    /**
     * Event indicating the viewer unmuted a convo. Can be direct or group.
     */
    @Serializable
    data class ChatBskyConvoDefsLogUnmuteConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogUnmuteConvo"
        }
    }

    /**
     * Event indicating a user-originated message was created. Is not emitted for system messages.
     */
    @Serializable
    data class ChatBskyConvoDefsLogCreateMessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogCreateMessageMessageUnion,/** Profiles referred to in the message view. This isn't required for compatibility, because it was added later, but should generally be present. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogCreateMessage"
        }
    }

    /**
     * Event indicating a user-originated message was deleted. Is not emitted for system messages.
     */
    @Serializable
    data class ChatBskyConvoDefsLogDeleteMessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogDeleteMessageMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogDeleteMessage"
        }
    }

    /**
     * DEPRECATED: use logReadConvo instead. Event indicating a convo was read up to a certain message.
     */
    @Serializable
    data class ChatBskyConvoDefsLogReadMessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogReadMessageMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogReadMessage"
        }
    }

    /**
     * Event indicating a reaction was added to a message.
     */
    @Serializable
    data class ChatBskyConvoDefsLogAddReaction(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogAddReactionMessageUnion,        @SerialName("reaction")
        val reaction: ChatBskyConvoDefsReactionView,/** Profiles referred in the message and reaction views. This isn't required for compatibility, because it was added later, but should generally be present. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogAddReaction"
        }
    }

    /**
     * Event indicating a reaction was removed from a message.
     */
    @Serializable
    data class ChatBskyConvoDefsLogRemoveReaction(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogRemoveReactionMessageUnion,        @SerialName("reaction")
        val reaction: ChatBskyConvoDefsReactionView,/** Profiles referred in the message and reaction views. This isn't required for compatibility, because it was added later, but should generally be present. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogRemoveReaction"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a convo was read up to a certain message.
     */
    @Serializable
    data class ChatBskyConvoDefsLogReadConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogReadConvoMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogReadConvo"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a member was added to a group convo. The member who was added gets a logBeginConvo (to create the convo) but also a logAddMember (to show the system message as the first message the user sees).
     */
    @Serializable
    data class ChatBskyConvoDefsLogAddMember(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataAddMember */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView,/** Profiles referred in the system message. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogAddMember"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a member was removed from a group convo. The member who was removed gets a logLeaveConvo (to leave the convo) but not a logRemoveMember (because they already left, so can't see the system message).
     */
    @Serializable
    data class ChatBskyConvoDefsLogRemoveMember(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataRemoveMember */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView,/** Profiles referred in the system message. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogRemoveMember"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a member joined a group convo via join link. The member who was added gets a logBeginConvo (to create the convo) but also a logMemberJoin (to show the system message as the first message the user sees).
     */
    @Serializable
    data class ChatBskyConvoDefsLogMemberJoin(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataMemberJoin */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView,/** Profiles referred in the system message. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogMemberJoin"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a member voluntarily left a group convo. The member who was removed gets a logLeaveConvo (to leave the convo) but not a logMemberLeave (because they already left, so can't see the system message).
     */
    @Serializable
    data class ChatBskyConvoDefsLogMemberLeave(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataMemberLeave */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView,/** Profiles referred in the system message. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogMemberLeave"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a group convo was locked.
     */
    @Serializable
    data class ChatBskyConvoDefsLogLockConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataLockConvo */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView,/** Profiles referred in the system message. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogLockConvo"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a group convo was unlocked.
     */
    @Serializable
    data class ChatBskyConvoDefsLogUnlockConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataUnlockConvo */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView,/** Profiles referred in the system message. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogUnlockConvo"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a group convo was locked permanently.
     */
    @Serializable
    data class ChatBskyConvoDefsLogLockConvoPermanently(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataLockConvoPermanently */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView,/** Profiles referred in the system message. */        @SerialName("relatedProfiles")
        val relatedProfiles: List<ChatBskyActorDefsProfileViewBasic>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogLockConvoPermanently"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating info about group convo was edited.
     */
    @Serializable
    data class ChatBskyConvoDefsLogEditGroup(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataEditGroup */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogEditGroup"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a join link was created for a group convo.
     */
    @Serializable
    data class ChatBskyConvoDefsLogCreateJoinLink(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataCreateJoinLink */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogCreateJoinLink"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a settings about a join link for a group convo were edited.
     */
    @Serializable
    data class ChatBskyConvoDefsLogEditJoinLink(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataEditJoinLink */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogEditJoinLink"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a join link was enabled for a group convo.
     */
    @Serializable
    data class ChatBskyConvoDefsLogEnableJoinLink(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataEnableJoinLink */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogEnableJoinLink"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a join link was disabled for a group convo.
     */
    @Serializable
    data class ChatBskyConvoDefsLogDisableJoinLink(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** A system message with data of type #systemMessageDataDisableJoinLink */        @SerialName("message")
        val message: ChatBskyConvoDefsSystemMessageView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogDisableJoinLink"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a join request was made to a group the viewer owns. Only the owner gets this.
     */
    @Serializable
    data class ChatBskyConvoDefsLogIncomingJoinRequest(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** Prospective member who requested to join. */        @SerialName("member")
        val member: ChatBskyActorDefsProfileViewBasic    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogIncomingJoinRequest"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a join request was approved by the viewer. Only the owner gets this. The approved member gets a logBeginConvo.
     */
    @Serializable
    data class ChatBskyConvoDefsLogApproveJoinRequest(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** Prospective member who requested to join. */        @SerialName("member")
        val member: ChatBskyActorDefsProfileViewBasic    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogApproveJoinRequest"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a join request was rejected by the viewer. Only the owner gets this.
     */
    @Serializable
    data class ChatBskyConvoDefsLogRejectJoinRequest(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** Prospective member who requested to join. */        @SerialName("member")
        val member: ChatBskyActorDefsProfileViewBasic    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogRejectJoinRequest"
        }
    }

    /**
     * [NOTE: This is under active development and should be considered unstable while this note is here]. Event indicating a join request was made by the viewer.
     */
    @Serializable
    data class ChatBskyConvoDefsLogOutgoingJoinRequest(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogOutgoingJoinRequest"
        }
    }
