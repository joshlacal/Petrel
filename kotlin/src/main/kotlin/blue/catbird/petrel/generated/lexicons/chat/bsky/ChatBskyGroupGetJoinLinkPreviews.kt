// Lexicon: 1, ID: chat.bsky.group.getJoinLinkPreviews
// Get public information about groups from join links. The output array matches the input codes one-to-one by position (and each view also carries its 'code'). Disabled codes return a disabledJoinLinkPreviewView, and codes that do not map to a previewable link return an invalidJoinLinkPreviewView.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupGetJoinLinkPreviewsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.getJoinLinkPreviews"
}

@Serializable(with = ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnionSerializer::class)
sealed interface ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion {
    @Serializable
    data class JoinLinkPreviewView(val value: blue.catbird.petrel.generated.ChatBskyGroupDefsJoinLinkPreviewView) : ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion

    @Serializable
    data class DisabledJoinLinkPreviewView(val value: blue.catbird.petrel.generated.ChatBskyGroupDefsDisabledJoinLinkPreviewView) : ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion

    @Serializable
    data class InvalidJoinLinkPreviewView(val value: blue.catbird.petrel.generated.ChatBskyGroupDefsInvalidJoinLinkPreviewView) : ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion
}

object ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.JoinLinkPreviewView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsJoinLinkPreviewView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#joinLinkPreviewView")
                })
            }
            is ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.DisabledJoinLinkPreviewView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsDisabledJoinLinkPreviewView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#disabledJoinLinkPreviewView")
                })
            }
            is ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.InvalidJoinLinkPreviewView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsInvalidJoinLinkPreviewView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#invalidJoinLinkPreviewView")
                })
            }
            is ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.group.defs#joinLinkPreviewView" -> ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.JoinLinkPreviewView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsJoinLinkPreviewView.serializer(), element)
            )
            "chat.bsky.group.defs#disabledJoinLinkPreviewView" -> ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.DisabledJoinLinkPreviewView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsDisabledJoinLinkPreviewView.serializer(), element)
            )
            "chat.bsky.group.defs#invalidJoinLinkPreviewView" -> ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.InvalidJoinLinkPreviewView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsInvalidJoinLinkPreviewView.serializer(), element)
            )
            else -> ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class ChatBskyGroupGetJoinLinkPreviewsParameters(
        @SerialName("codes")
        val codes: List<String>    )

    @Serializable
    data class ChatBskyGroupGetJoinLinkPreviewsOutput(
        @SerialName("joinLinkPreviews")
        val joinLinkPreviews: List<ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion>    )

/**
 * Get public information about groups from join links. The output array matches the input codes one-to-one by position (and each view also carries its 'code'). Disabled codes return a disabledJoinLinkPreviewView, and codes that do not map to a previewable link return an invalidJoinLinkPreviewView.
 *
 * Endpoint: chat.bsky.group.getJoinLinkPreviews
 */
suspend fun ATProtoClient.Chat.Bsky.Group.getJoinLinkPreviews(
parameters: ChatBskyGroupGetJoinLinkPreviewsParameters): ATProtoResponse<ChatBskyGroupGetJoinLinkPreviewsOutput> {
    val endpoint = "chat.bsky.group.getJoinLinkPreviews"

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
