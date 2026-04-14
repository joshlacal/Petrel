// Lexicon: 1, ID: chat.bsky.convo.getMessages

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ChatBskyConvoGetMessagesDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.getMessages"
}

@Serializable(with = ChatBskyConvoGetMessagesOutputMessagesUnionSerializer::class)
sealed interface ChatBskyConvoGetMessagesOutputMessagesUnion {
    @Serializable
    data class MessageView(val value: com.atproto.generated.ChatBskyConvoDefsMessageView) : ChatBskyConvoGetMessagesOutputMessagesUnion

    @Serializable
    data class DeletedMessageView(val value: com.atproto.generated.ChatBskyConvoDefsDeletedMessageView) : ChatBskyConvoGetMessagesOutputMessagesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoGetMessagesOutputMessagesUnion
}

object ChatBskyConvoGetMessagesOutputMessagesUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoGetMessagesOutputMessagesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoGetMessagesOutputMessagesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoGetMessagesOutputMessagesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoGetMessagesOutputMessagesUnion.MessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#messageView")
                })
            }
            is ChatBskyConvoGetMessagesOutputMessagesUnion.DeletedMessageView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#deletedMessageView")
                })
            }
            is ChatBskyConvoGetMessagesOutputMessagesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoGetMessagesOutputMessagesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#messageView" -> ChatBskyConvoGetMessagesOutputMessagesUnion.MessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsMessageView.serializer(), element)
            )
            "chat.bsky.convo.defs#deletedMessageView" -> ChatBskyConvoGetMessagesOutputMessagesUnion.DeletedMessageView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsDeletedMessageView.serializer(), element)
            )
            else -> ChatBskyConvoGetMessagesOutputMessagesUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class ChatBskyConvoGetMessagesParameters(
        @SerialName("convoId")
        val convoId: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ChatBskyConvoGetMessagesOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("messages")
        val messages: List<ChatBskyConvoGetMessagesOutputMessagesUnion>    )

/**
 * 
 *
 * Endpoint: chat.bsky.convo.getMessages
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.getMessages(
parameters: ChatBskyConvoGetMessagesParameters): ATProtoResponse<ChatBskyConvoGetMessagesOutput> {
    val endpoint = "chat.bsky.convo.getMessages"

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
