// Lexicon: 1, ID: chat.bsky.moderation.getMessageContext

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyModerationGetMessageContextDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.moderation.getMessageContext"
}

@Serializable(with = ChatBskyModerationGetMessageContextOutputMessagesUnionSerializer::class)
sealed interface ChatBskyModerationGetMessageContextOutputMessagesUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyModerationGetMessageContextOutputMessagesUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyModerationGetMessageContextOutputMessagesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyModerationGetMessageContextOutputMessagesUnion
}

object ChatBskyModerationGetMessageContextOutputMessagesUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyModerationGetMessageContextOutputMessagesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyModerationGetMessageContextOutputMessagesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyModerationGetMessageContextOutputMessagesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyModerationGetMessageContextOutputMessagesUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyModerationGetMessageContextOutputMessagesUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyModerationGetMessageContextOutputMessagesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyModerationGetMessageContextOutputMessagesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyModerationGetMessageContextOutputMessagesUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyModerationGetMessageContextOutputMessagesUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyModerationGetMessageContextOutputMessagesUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class ChatBskyModerationGetMessageContextParameters(
// Conversation that the message is from. NOTE: this field will eventually be required.        @SerialName("convoId")
        val convoId: String? = null,        @SerialName("messageId")
        val messageId: String,        @SerialName("before")
        val before: Int? = null,        @SerialName("after")
        val after: Int? = null    )

    @Serializable
    data class ChatBskyModerationGetMessageContextOutput(
        @SerialName("messages")
        val messages: List<ChatBskyModerationGetMessageContextOutputMessagesUnion>    )

/**
 * 
 *
 * Endpoint: chat.bsky.moderation.getMessageContext
 */
suspend fun ATProtoClient.Chat.Bsky.Moderation.getMessageContext(
parameters: ChatBskyModerationGetMessageContextParameters): ATProtoResponse<ChatBskyModerationGetMessageContextOutput> {
    val endpoint = "chat.bsky.moderation.getMessageContext"

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
