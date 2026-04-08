// Lexicon: 1, ID: app.bsky.graph.list
// Record representing a list of accounts (actors). Scope includes both moderation-oriented lists and curration-oriented lists.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphListDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.list"
}

@Serializable(with = AppBskyGraphListLabelsUnionSerializer::class)
sealed interface AppBskyGraphListLabelsUnion {
    @Serializable
    data class SelfLabels(val value: com.atproto.generated.ComAtprotoLabelDefsSelfLabels) : AppBskyGraphListLabelsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyGraphListLabelsUnion
}

object AppBskyGraphListLabelsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyGraphListLabelsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyGraphListLabelsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyGraphListLabelsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyGraphListLabelsUnion.SelfLabels -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.defs#selfLabels")
                })
            }
            is AppBskyGraphListLabelsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyGraphListLabelsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.label.defs#selfLabels" -> AppBskyGraphListLabelsUnion.SelfLabels(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), element)
            )
            else -> AppBskyGraphListLabelsUnion.Unexpected(element)
        }
    }
}

    /**
     * Record representing a list of accounts (actors). Scope includes both moderation-oriented lists and curration-oriented lists.
     */
    @Serializable
    data class AppBskyGraphList(
/** Defines the purpose of the list (aka, moderation-oriented or curration-oriented) */        @SerialName("purpose")
        val purpose: AppBskyGraphDefsListPurpose,/** Display name for list; can not be empty. */        @SerialName("name")
        val name: String,        @SerialName("description")
        val description: String? = null,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>? = null,        @SerialName("avatar")
        val avatar: Blob? = null,        @SerialName("labels")
        val labels: AppBskyGraphListLabelsUnion? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
