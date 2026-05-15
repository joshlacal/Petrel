// Lexicon: 1, ID: chat.bsky.convo.listConvoRequests
// [NOTE: This is under active development and should be considered unstable while this note is here]. Returns a page of incoming conversation requests for the user. Direct convo requests are returned as convoView; group join requests are returned as joinRequestView.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoListConvoRequestsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.listConvoRequests"
}

@Serializable(with = ChatBskyConvoListConvoRequestsOutputRequestsUnionSerializer::class)
sealed interface ChatBskyConvoListConvoRequestsOutputRequestsUnion {
    @Serializable
    data class ConvoView(val value: com.atproto.generated.ChatBskyConvoDefsConvoView) : ChatBskyConvoListConvoRequestsOutputRequestsUnion

    @Serializable
    data class JoinRequestView(val value: com.atproto.generated.ChatBskyGroupDefsJoinRequestView) : ChatBskyConvoListConvoRequestsOutputRequestsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyConvoListConvoRequestsOutputRequestsUnion
}

object ChatBskyConvoListConvoRequestsOutputRequestsUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyConvoListConvoRequestsOutputRequestsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyConvoListConvoRequestsOutputRequestsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyConvoListConvoRequestsOutputRequestsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyConvoListConvoRequestsOutputRequestsUnion.ConvoView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyConvoDefsConvoView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#convoView")
                })
            }
            is ChatBskyConvoListConvoRequestsOutputRequestsUnion.JoinRequestView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyGroupDefsJoinRequestView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#joinRequestView")
                })
            }
            is ChatBskyConvoListConvoRequestsOutputRequestsUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyConvoListConvoRequestsOutputRequestsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.convo.defs#convoView" -> ChatBskyConvoListConvoRequestsOutputRequestsUnion.ConvoView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyConvoDefsConvoView.serializer(), element)
            )
            "chat.bsky.group.defs#joinRequestView" -> ChatBskyConvoListConvoRequestsOutputRequestsUnion.JoinRequestView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyGroupDefsJoinRequestView.serializer(), element)
            )
            else -> ChatBskyConvoListConvoRequestsOutputRequestsUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class ChatBskyConvoListConvoRequestsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class ChatBskyConvoListConvoRequestsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("requests")
        val requests: List<ChatBskyConvoListConvoRequestsOutputRequestsUnion>    )

/**
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Returns a page of incoming conversation requests for the user. Direct convo requests are returned as convoView; group join requests are returned as joinRequestView.
 *
 * Endpoint: chat.bsky.convo.listConvoRequests
 */
suspend fun ATProtoClient.Chat.Bsky.Convo.listConvoRequests(
parameters: ChatBskyConvoListConvoRequestsParameters): ATProtoResponse<ChatBskyConvoListConvoRequestsOutput> {
    val endpoint = "chat.bsky.convo.listConvoRequests"

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
