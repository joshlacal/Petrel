// Lexicon: 1, ID: chat.bsky.convo.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

@Serializable(with = ChatBskyConvoDefsConvoViewLastMessageUnionSerializer::class)
sealed interface ChatBskyConvoDefsConvoViewLastMessageUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoDefsConvoViewLastMessageUnion

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
            is ChatBskyConvoDefsConvoViewLastMessageUnion.Unexpected -> value.value
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
            is ChatBskyConvoDefsLogReadMessageMessageUnion.Unexpected -> value.value
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
        val rev: String,        @SerialName("members")
        val members: List<ChatBskyActorDefsProfileViewBasic>,        @SerialName("lastMessage")
        val lastMessage: ChatBskyConvoDefsConvoViewLastMessageUnion? = null,        @SerialName("lastReaction")
        val lastReaction: ChatBskyConvoDefsConvoViewLastReactionUnion? = null,        @SerialName("muted")
        val muted: Boolean,        @SerialName("status")
        val status: String? = null,        @SerialName("unreadCount")
        val unreadCount: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsConvoView"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogBeginConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogBeginConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogAcceptConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogAcceptConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogLeaveConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogLeaveConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogMuteConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogMuteConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogUnmuteConvo(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogUnmuteConvo"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogCreateMessage(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogCreateMessageMessageUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogCreateMessage"
        }
    }

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

    @Serializable
    data class ChatBskyConvoDefsLogAddReaction(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogAddReactionMessageUnion,        @SerialName("reaction")
        val reaction: ChatBskyConvoDefsReactionView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogAddReaction"
        }
    }

    @Serializable
    data class ChatBskyConvoDefsLogRemoveReaction(
        @SerialName("rev")
        val rev: String,        @SerialName("convoId")
        val convoId: String,        @SerialName("message")
        val message: ChatBskyConvoDefsLogRemoveReactionMessageUnion,        @SerialName("reaction")
        val reaction: ChatBskyConvoDefsReactionView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyConvoDefsLogRemoveReaction"
        }
    }
