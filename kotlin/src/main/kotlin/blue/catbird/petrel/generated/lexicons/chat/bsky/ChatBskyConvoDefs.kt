// Lexicon: 1, ID: chat.bsky.convo.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoDefsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.defs"
}

@Serializable(with = ChatBskyConvoDefsMessageInputEmbedUnionSerializer::class)
sealed interface ChatBskyConvoDefsMessageInputEmbedUnion {
    @Serializable
    data class Record(val value: blue.catbird.petrel.generated.AppBskyEmbedRecord) : ChatBskyConvoDefsMessageInputEmbedUnion

    @Serializable
    data class JoinLink(val value: blue.catbird.petrel.generated.ChatBskyEmbedJoinLink) : ChatBskyConvoDefsMessageInputEmbedUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecord.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record")
                })
            }
            is ChatBskyConvoDefsMessageInputEmbedUnion.JoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyEmbedJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.embed.joinLink")
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecord.serializer(), element)
            )
            "chat.bsky.embed.joinLink" -> ChatBskyConvoDefsMessageInputEmbedUnion.JoinLink(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyEmbedJoinLink.serializer(), element)
            )
            else -> ChatBskyConvoDefsMessageInputEmbedUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsMessageViewEmbedUnionSerializer::class)
sealed interface ChatBskyConvoDefsMessageViewEmbedUnion {
    @Serializable
    data class View(val value: blue.catbird.petrel.generated.AppBskyEmbedRecordView) : ChatBskyConvoDefsMessageViewEmbedUnion

    @Serializable
    data class ChatBskyEmbedJoinLinkView(val value: blue.catbird.petrel.generated.ChatBskyEmbedJoinLinkView) : ChatBskyConvoDefsMessageViewEmbedUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#view")
                })
            }
            is ChatBskyConvoDefsMessageViewEmbedUnion.ChatBskyEmbedJoinLinkView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyEmbedJoinLinkView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.embed.joinLink#view")
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedRecordView.serializer(), element)
            )
            "chat.bsky.embed.joinLink#view" -> ChatBskyConvoDefsMessageViewEmbedUnion.ChatBskyEmbedJoinLinkView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyEmbedJoinLinkView.serializer(), element)
            )
            else -> ChatBskyConvoDefsMessageViewEmbedUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsMessageViewReplyToUnionSerializer::class)
sealed interface ChatBskyConvoDefsMessageViewReplyToUnion {
    @Serializable
    data class MessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsMessageViewReplyToUnion

    @Serializable
    data class DeletedMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsMessageViewReplyToUnion

    @Serializable
    data class MessageBeforeUserJoinedGroupView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageBeforeUserJoinedGroupView) : ChatBskyConvoDefsMessageViewReplyToUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoDefsMessageViewReplyToUnion
}

object ChatBskyConvoDefsMessageViewReplyToUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoDefsMessageViewReplyToUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoDefsMessageViewReplyToUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoDefsMessageViewReplyToUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoDefsMessageViewReplyToUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsMessageViewReplyToUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsMessageViewReplyToUnion.MessageBeforeUserJoinedGroupView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageBeforeUserJoinedGroupView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageBeforeUserJoinedGroupView")
                })
            }
            is ChatBskyConvoDefsMessageViewReplyToUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoDefsMessageViewReplyToUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyConvoDefsMessageViewReplyToUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsMessageViewReplyToUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#messageBeforeUserJoinedGroupView" -> ChatBskyConvoDefsMessageViewReplyToUnion.MessageBeforeUserJoinedGroupView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageBeforeUserJoinedGroupView.serializer(), element)
            )
            else -> ChatBskyConvoDefsMessageViewReplyToUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsSystemMessageViewDataUnionSerializer::class)
sealed interface ChatBskyConvoDefsSystemMessageViewDataUnion {
    @Serializable
    data class SystemMessageDataAddMember(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataAddMember) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataRemoveMember(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataRemoveMember) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataMemberJoin(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataMemberJoin) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataMemberLeave(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataMemberLeave) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataLockConvo(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataLockConvo) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataUnlockConvo(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataUnlockConvo) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataLockConvoPermanently(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataLockConvoPermanently) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataEditGroup(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataEditGroup) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataCreateJoinLink(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataCreateJoinLink) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataEditJoinLink(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataEditJoinLink) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataEnableJoinLink(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataEnableJoinLink) : ChatBskyConvoDefsSystemMessageViewDataUnion

    @Serializable
    data class SystemMessageDataDisableJoinLink(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataDisableJoinLink) : ChatBskyConvoDefsSystemMessageViewDataUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataAddMember.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataAddMember")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataRemoveMember -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataRemoveMember.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataRemoveMember")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataMemberJoin -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataMemberJoin.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataMemberJoin")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataMemberLeave -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataMemberLeave.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataMemberLeave")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataLockConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataLockConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataLockConvo")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataUnlockConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataUnlockConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataUnlockConvo")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataLockConvoPermanently -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataLockConvoPermanently.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataLockConvoPermanently")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEditGroup -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataEditGroup.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataEditGroup")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataCreateJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataCreateJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataCreateJoinLink")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEditJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataEditJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataEditJoinLink")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEnableJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataEnableJoinLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#systemMessageDataEnableJoinLink")
                })
            }
            is ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataDisableJoinLink -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataDisableJoinLink.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataAddMember.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataRemoveMember" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataRemoveMember(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataRemoveMember.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataMemberJoin" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataMemberJoin(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataMemberJoin.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataMemberLeave" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataMemberLeave(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataMemberLeave.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataLockConvo" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataLockConvo(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataLockConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataUnlockConvo" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataUnlockConvo(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataUnlockConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataLockConvoPermanently" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataLockConvoPermanently(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataLockConvoPermanently.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataEditGroup" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEditGroup(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataEditGroup.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataCreateJoinLink" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataCreateJoinLink(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataCreateJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataEditJoinLink" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEditJoinLink(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataEditJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataEnableJoinLink" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataEnableJoinLink(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataEnableJoinLink.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageDataDisableJoinLink" -> ChatBskyConvoDefsSystemMessageViewDataUnion.SystemMessageDataDisableJoinLink(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageDataDisableJoinLink.serializer(), element)
            )
            else -> ChatBskyConvoDefsSystemMessageViewDataUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsConvoViewLastMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsConvoViewLastMessageUnion {
    @Serializable
    data class MessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

    @Serializable
    data class DeletedMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

    @Serializable
    data class SystemMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsConvoViewLastMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsConvoViewLastMessageUnion.SystemMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageView.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsConvoViewLastMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageView" -> ChatBskyConvoDefsConvoViewLastMessageUnion.SystemMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsConvoViewLastMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsConvoViewLastReactionUnionSerializer::class)
sealed interface ChatBskyConvoDefsConvoViewLastReactionUnion {
    @Serializable
    data class MessageAndReactionView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageAndReactionView) : ChatBskyConvoDefsConvoViewLastReactionUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageAndReactionView.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageAndReactionView.serializer(), element)
            )
            else -> ChatBskyConvoDefsConvoViewLastReactionUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsConvoViewKindUnionSerializer::class)
sealed interface ChatBskyConvoDefsConvoViewKindUnion {
    @Serializable
    data class DirectConvo(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsDirectConvo) : ChatBskyConvoDefsConvoViewKindUnion

    @Serializable
    data class GroupConvo(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsGroupConvo) : ChatBskyConvoDefsConvoViewKindUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDirectConvo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#directConvo")
                })
            }
            is ChatBskyConvoDefsConvoViewKindUnion.GroupConvo -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsGroupConvo.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDirectConvo.serializer(), element)
            )
            "chat.bsky.convo.defs#groupConvo" -> ChatBskyConvoDefsConvoViewKindUnion.GroupConvo(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsGroupConvo.serializer(), element)
            )
            else -> ChatBskyConvoDefsConvoViewKindUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogCreateMessageMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogCreateMessageMessageUnion {
    @Serializable
    data class MessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogCreateMessageMessageUnion

    @Serializable
    data class DeletedMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogCreateMessageMessageUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogCreateMessageMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogCreateMessageMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogCreateMessageMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogDeleteMessageMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogDeleteMessageMessageUnion {
    @Serializable
    data class MessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogDeleteMessageMessageUnion

    @Serializable
    data class DeletedMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogDeleteMessageMessageUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogDeleteMessageMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogDeleteMessageMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogDeleteMessageMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogReadMessageMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogReadMessageMessageUnion {
    @Serializable
    data class MessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogReadMessageMessageUnion

    @Serializable
    data class DeletedMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogReadMessageMessageUnion

    @Serializable
    data class SystemMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageView) : ChatBskyConvoDefsLogReadMessageMessageUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogReadMessageMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsLogReadMessageMessageUnion.SystemMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageView.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogReadMessageMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageView" -> ChatBskyConvoDefsLogReadMessageMessageUnion.SystemMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogReadMessageMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogAddReactionMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogAddReactionMessageUnion {
    @Serializable
    data class MessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogAddReactionMessageUnion

    @Serializable
    data class DeletedMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogAddReactionMessageUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogAddReactionMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogAddReactionMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogAddReactionMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogRemoveReactionMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogRemoveReactionMessageUnion {
    @Serializable
    data class MessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogRemoveReactionMessageUnion

    @Serializable
    data class DeletedMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogRemoveReactionMessageUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogRemoveReactionMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogRemoveReactionMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyConvoDefsLogRemoveReactionMessageUnion.Unexpected(element)
        }
    }
}

@Serializable(with = ChatBskyConvoDefsLogReadConvoMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsLogReadConvoMessageUnion {
    @Serializable
    data class MessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsLogReadConvoMessageUnion

    @Serializable
    data class DeletedMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsLogReadConvoMessageUnion

    @Serializable
    data class SystemMessageView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageView) : ChatBskyConvoDefsLogReadConvoMessageUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoDefsLogReadConvoMessageUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoDefsLogReadConvoMessageUnion.SystemMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageView.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoDefsLogReadConvoMessageUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#systemMessageView" -> ChatBskyConvoDefsLogReadConvoMessageUnion.SystemMessageView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsSystemMessageView.serializer(), element)
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
    data class ChatBskyConvoDefsConvoRef(
        @SerialName("did")
        val did: DID,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsConvoRef"
        }
    }

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
        val embed: ChatBskyConvoDefsMessageInputEmbedUnion? = null,/** If set, the message this message is replying to. The referenced message must be in the same convo. */        @SerialName("replyTo")
        val replyTo: ChatBskyConvoDefsReplyRef? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageInput"
        }
    }

    /**
     * A reference to another message within the same convo, used to indicate that a message is a reply to it.
     */
    @Serializable
    data class ChatBskyConvoDefsReplyRef(
        @SerialName("messageId")
        val messageId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsReplyRef"
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
        val reactions: List<ChatBskyConvoDefsReactionView>? = null,/** If set, the message this message is replying to. The full view of the referenced message is embedded so the client can render it inline. Only a single level is embedded: the embedded message will not itself have a populated 'replyTo' field even if it was also a reply. */        @SerialName("replyTo")
        val replyTo: ChatBskyConvoDefsMessageViewReplyToUnion? = null,        @SerialName("sender")
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
     * System message indicating a user was added to the group convo.
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
     * System message indicating a user was removed from the group convo.
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
     * System message indicating a user joined the group convo via join link.
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
     * System message indicating a user voluntarily left the group convo.
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
     * System message indicating the group convo was locked.
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
     * System message indicating the group convo was unlocked.
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
     * System message indicating the group convo was locked permanently.
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
     * System message indicating the group info was edited.
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
     * System message indicating the group join link was created.
     */
    @Serializable
    class ChatBskyConvoDefsSystemMessageDataCreateJoinLink {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataCreateJoinLink"
        }
    }

    /**
     * System message indicating the group join link was edited.
     */
    @Serializable
    class ChatBskyConvoDefsSystemMessageDataEditJoinLink {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataEditJoinLink"
        }
    }

    /**
     * System message indicating the group join link was enabled.
     */
    @Serializable
    class ChatBskyConvoDefsSystemMessageDataEnableJoinLink {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsSystemMessageDataEnableJoinLink"
        }
    }

    /**
     * System message indicating the group join link was disabled.
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

    /**
     * Placeholder embedded in place of a reply's parent message when that parent was sent before the viewer joined the group convo. The viewer has no access to that history, so no message data is carried.
     */
    @Serializable
    class ChatBskyConvoDefsMessageBeforeUserJoinedGroupView {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsMessageBeforeUserJoinedGroupView"
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
        val rev: String,/** Members of this conversation. For direct convos, it will be an immutable list of the 2 members. For group convos, it will a list of important members (the first few members, the viewer, the member who added the viewer, the member who sent the last message, the member who sent the last reaction), but will not contain the full list of members. Use chat.bsky.convo.getConvoMembers to list all members. */        @SerialName("members")
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

    @Serializable
    class ChatBskyConvoDefsDirectConvo {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsDirectConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsGroupConvo(
        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("joinLink")
        val joinLink: ChatBskyGroupDefsJoinLinkView? = null,/** The total number of pending join requests for the group conversation. Only present for the owner. Capped at 21. */        @SerialName("joinRequestCount")
        val joinRequestCount: Int? = null,/** The lock status of the conversation. */        @SerialName("lockStatus")
        val lockStatus: ChatBskyConvoDefsConvoLockStatus,/** Whether the lock status is being forced by a moderation override (account inactivation or convo takedown) rather than the owner's own setting. */        @SerialName("lockStatusModerationOverride")
        val lockStatusModerationOverride: Boolean,/** The total number of members in the group conversation. */        @SerialName("memberCount")
        val memberCount: Int,/** The maximum number of members allowed in the group conversation. */        @SerialName("memberLimit")
        val memberLimit: Int,/** The display name of the group conversation. */        @SerialName("name")
        val name: String,/** The number of unread join requests for the group conversation. Only present for the owner. */        @SerialName("unreadJoinRequestCount")
        val unreadJoinRequestCount: Int? = null    ) {
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
     * Event indicating a convo was read up to a certain message.
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
     * Event indicating a member was added to a group convo. The member who was added gets a logBeginConvo (to create the convo) but also a logAddMember (to show the system message as the first message the user sees).
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
     * Event indicating a member was removed from a group convo. The member who was removed gets a logLeaveConvo (to leave the convo) but not a logRemoveMember (because they already left, so can't see the system message).
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
     * Event indicating a member joined a group convo via join link. The member who was added gets a logBeginConvo (to create the convo) but also a logMemberJoin (to show the system message as the first message the user sees).
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
     * Event indicating a member voluntarily left a group convo. The member who was removed gets a logLeaveConvo (to leave the convo) but not a logMemberLeave (because they already left, so can't see the system message).
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
     * Event indicating a group convo was locked.
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
     * Event indicating a group convo was unlocked.
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
     * Event indicating a group convo was locked permanently.
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
     * Event indicating info about group convo was edited.
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
     * Event indicating a join link was created for a group convo.
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
     * Event indicating a settings about a join link for a group convo were edited.
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
     * Event indicating a join link was enabled for a group convo.
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
     * Event indicating a join link was disabled for a group convo.
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
     * Event indicating a join request was made to a group the viewer owns. Only the owner gets this.
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
     * Event indicating a join request was approved by the viewer. Only the owner gets this. The approved member gets a logBeginConvo.
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
     * Event indicating a join request was rejected by the viewer. Only the owner gets this.
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
     * Event indicating a join request was made by the requester. Only requester actor gets this.
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

    /**
     * Event indicating a prospective member withdrew their join request. Only the owner gets this.
     */
    @Serializable
    data class ChatBskyConvoDefsLogWithdrawIncomingJoinRequest(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,/** Prospective member who withdrew their join request. */        @SerialName("member")
        val member: ChatBskyActorDefsProfileViewBasic    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogWithdrawIncomingJoinRequest"
        }
    }

    /**
     * Event indicating the viewer withdrew their own join request. Only requester actor gets this.
     */
    @Serializable
    data class ChatBskyConvoDefsLogWithdrawOutgoingJoinRequest(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogWithdrawOutgoingJoinRequest"
        }
    }

    /**
     * Event indicating the group owner marked join requests as read. Only the owner gets this.
     */
    @Serializable
    data class ChatBskyConvoDefsLogReadJoinRequests(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogReadJoinRequests"
        }
    }
