// Lexicon: 1, ID: app.bsky.feed.generator
// Record declaring of the existence of a feed generator, and containing metadata about it. The record can exist in any repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGeneratorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.generator"
}

@Serializable(with = AppBskyFeedGeneratorLabelsUnionSerializer::class)
sealed interface AppBskyFeedGeneratorLabelsUnion {
    @Serializable
    data class SelfLabels(val value: com.atproto.generated.ComAtprotoLabelDefsSelfLabels) : AppBskyFeedGeneratorLabelsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedGeneratorLabelsUnion
}

object AppBskyFeedGeneratorLabelsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedGeneratorLabelsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedGeneratorLabelsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedGeneratorLabelsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedGeneratorLabelsUnion.SelfLabels -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.defs#selfLabels")
                })
            }
            is AppBskyFeedGeneratorLabelsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedGeneratorLabelsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.label.defs#selfLabels" -> AppBskyFeedGeneratorLabelsUnion.SelfLabels(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), element)
            )
            else -> AppBskyFeedGeneratorLabelsUnion.Unexpected(element)
        }
    }
}

    /**
     * Record declaring of the existence of a feed generator, and containing metadata about it. The record can exist in any repository.
     */
    @Serializable
    data class AppBskyFeedGenerator(
        @SerialName("did")
        val did: DID,        @SerialName("displayName")
        val displayName: String,        @SerialName("description")
        val description: String? = null,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>? = null,        @SerialName("avatar")
        val avatar: Blob? = null,/** Declaration that a feed accepts feedback interactions from a client through app.bsky.feed.sendInteractions */        @SerialName("acceptsInteractions")
        val acceptsInteractions: Boolean? = null,/** Self-label values */        @SerialName("labels")
        val labels: AppBskyFeedGeneratorLabelsUnion? = null,        @SerialName("contentMode")
        val contentMode: String? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
