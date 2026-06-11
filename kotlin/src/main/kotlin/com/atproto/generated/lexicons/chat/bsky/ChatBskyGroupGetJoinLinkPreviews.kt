// Lexicon: 1, ID: chat.bsky.group.getJoinLinkPreviews
// [NOTE: This is under active development and should be considered unstable while this note is here]. Get public information about groups from join links. The output array matches the input codes one-to-one by position (and each view also carries its 'code'). Disabled codes return a disabledJoinLinkPreviewView, and codes that do not map to a previewable link return an invalidJoinLinkPreviewView.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyGroupGetJoinLinkPreviewsDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.group.getJoinLinkPreviews"
}

@Serializable(with = ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnionSerializer::class)
sealed interface ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion {
    @Serializable
    data class JoinLinkPreviewView(val value: com.atproto.generated.ChatBskyGroupDefsJoinLinkPreviewView) : ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion

    @Serializable
    data class DisabledJoinLinkPreviewView(val value: com.atproto.generated.ChatBskyGroupDefsDisabledJoinLinkPreviewView) : ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion

    @Serializable
    data class InvalidJoinLinkPreviewView(val value: com.atproto.generated.ChatBskyGroupDefsInvalidJoinLinkPreviewView) : ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyGroupDefsJoinLinkPreviewView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#joinLinkPreviewView")
                })
            }
            is ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.DisabledJoinLinkPreviewView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyGroupDefsDisabledJoinLinkPreviewView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#disabledJoinLinkPreviewView")
                })
            }
            is ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.InvalidJoinLinkPreviewView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ChatBskyGroupDefsInvalidJoinLinkPreviewView.serializer(), value.value)
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
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyGroupDefsJoinLinkPreviewView.serializer(), element)
            )
            "chat.bsky.group.defs#disabledJoinLinkPreviewView" -> ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.DisabledJoinLinkPreviewView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyGroupDefsDisabledJoinLinkPreviewView.serializer(), element)
            )
            "chat.bsky.group.defs#invalidJoinLinkPreviewView" -> ChatBskyGroupGetJoinLinkPreviewsOutputJoinLinkPreviewsUnion.InvalidJoinLinkPreviewView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ChatBskyGroupDefsInvalidJoinLinkPreviewView.serializer(), element)
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
 * [NOTE: This is under active development and should be considered unstable while this note is here]. Get public information about groups from join links. The output array matches the input codes one-to-one by position (and each view also carries its 'code'). Disabled codes return a disabledJoinLinkPreviewView, and codes that do not map to a previewable link return an invalidJoinLinkPreviewView.
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
