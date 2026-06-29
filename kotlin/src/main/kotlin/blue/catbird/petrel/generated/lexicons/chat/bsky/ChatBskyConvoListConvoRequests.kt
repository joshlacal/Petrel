// Lexicon: 1, ID: chat.bsky.convo.listConvoRequests
// Returns a page of incoming conversation requests for the user. Direct convo requests are returned as convoView; group join requests made by the user are returned as joinRequestConvoView.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyConvoListConvoRequestsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.convo.listConvoRequests"
}

@Serializable(with = ChatBskyConvoListConvoRequestsOutputRequestsUnionSerializer::class)
sealed interface ChatBskyConvoListConvoRequestsOutputRequestsUnion {
    @Serializable
    data class ConvoView(val value: blue.catbird.petrel.generated.ChatBskyConvoDefsConvoView) : ChatBskyConvoListConvoRequestsOutputRequestsUnion

    @Serializable
    data class JoinRequestConvoView(val value: blue.catbird.petrel.generated.ChatBskyGroupDefsJoinRequestConvoView) : ChatBskyConvoListConvoRequestsOutputRequestsUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsConvoView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.convo.defs#convoView")
                })
            }
            is ChatBskyConvoListConvoRequestsOutputRequestsUnion.JoinRequestConvoView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsJoinRequestConvoView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#joinRequestConvoView")
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
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyConvoDefsConvoView.serializer(), element)
            )
            "chat.bsky.group.defs#joinRequestConvoView" -> ChatBskyConvoListConvoRequestsOutputRequestsUnion.JoinRequestConvoView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsJoinRequestConvoView.serializer(), element)
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
 * Returns a page of incoming conversation requests for the user. Direct convo requests are returned as convoView; group join requests made by the user are returned as joinRequestConvoView.
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
