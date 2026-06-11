// Lexicon: 1, ID: chat.bsky.embed.joinLink
// [NOTE: This is under active development and should be considered unstable while this note is here]. A join link embedded in a chat message.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ChatBskyEmbedJoinLinkDefs {
    const val TYPE_IDENTIFIER = "chat.bsky.embed.joinLink"
}

@Serializable(with = ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnionSerializer::class)
sealed interface ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion {
    @Serializable
    data class JoinLinkPreviewView(val value: blue.catbird.petrel.generated.ChatBskyGroupDefsJoinLinkPreviewView) : ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion

    @Serializable
    data class DisabledJoinLinkPreviewView(val value: blue.catbird.petrel.generated.ChatBskyGroupDefsDisabledJoinLinkPreviewView) : ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion

    @Serializable
    data class InvalidJoinLinkPreviewView(val value: blue.catbird.petrel.generated.ChatBskyGroupDefsInvalidJoinLinkPreviewView) : ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion
}

object ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnionSerializer : kotlinx.serialization.KSerializer<ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion.JoinLinkPreviewView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsJoinLinkPreviewView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#joinLinkPreviewView")
                })
            }
            is ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion.DisabledJoinLinkPreviewView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsDisabledJoinLinkPreviewView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#disabledJoinLinkPreviewView")
                })
            }
            is ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion.InvalidJoinLinkPreviewView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsInvalidJoinLinkPreviewView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("chat.bsky.group.defs#invalidJoinLinkPreviewView")
                })
            }
            is ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "chat.bsky.group.defs#joinLinkPreviewView" -> ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion.JoinLinkPreviewView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsJoinLinkPreviewView.serializer(), element)
            )
            "chat.bsky.group.defs#disabledJoinLinkPreviewView" -> ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion.DisabledJoinLinkPreviewView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsDisabledJoinLinkPreviewView.serializer(), element)
            )
            "chat.bsky.group.defs#invalidJoinLinkPreviewView" -> ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion.InvalidJoinLinkPreviewView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.ChatBskyGroupDefsInvalidJoinLinkPreviewView.serializer(), element)
            )
            else -> ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class ChatBskyEmbedJoinLinkView(
        @SerialName("joinLinkPreview")
        val joinLinkPreview: ChatBskyEmbedJoinLinkViewJoinLinkPreviewUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#chatBskyEmbedJoinLinkView"
        }
    }

@Serializable
data class ChatBskyEmbedJoinLink(
// The join link code.    @SerialName("code")
    val code: String)
