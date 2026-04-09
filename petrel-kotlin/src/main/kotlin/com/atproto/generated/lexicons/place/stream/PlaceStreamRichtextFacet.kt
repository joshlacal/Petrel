// Lexicon: 1, ID: place.stream.richtext.facet
// Annotation of a sub-string within rich text.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamRichtextFacetDefs {
    const val TYPE_IDENTIFIER = "place.stream.richtext.facet"
}

@Serializable(with = PlaceStreamRichtextFacetFeaturesUnionSerializer::class)
sealed interface PlaceStreamRichtextFacetFeaturesUnion {
    @Serializable
    data class Mention(val value: com.atproto.generated.AppBskyRichtextFacetMention) : PlaceStreamRichtextFacetFeaturesUnion

    @Serializable
    data class Link(val value: com.atproto.generated.AppBskyRichtextFacetLink) : PlaceStreamRichtextFacetFeaturesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : PlaceStreamRichtextFacetFeaturesUnion
}

object PlaceStreamRichtextFacetFeaturesUnionSerializer : kotlinx.serialization.KSerializer<PlaceStreamRichtextFacetFeaturesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("PlaceStreamRichtextFacetFeaturesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: PlaceStreamRichtextFacetFeaturesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is PlaceStreamRichtextFacetFeaturesUnion.Mention -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyRichtextFacetMention.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.richtext.facet#mention")
                })
            }
            is PlaceStreamRichtextFacetFeaturesUnion.Link -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyRichtextFacetLink.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.richtext.facet#link")
                })
            }
            is PlaceStreamRichtextFacetFeaturesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): PlaceStreamRichtextFacetFeaturesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.richtext.facet#mention" -> PlaceStreamRichtextFacetFeaturesUnion.Mention(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyRichtextFacetMention.serializer(), element)
            )
            "app.bsky.richtext.facet#link" -> PlaceStreamRichtextFacetFeaturesUnion.Link(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyRichtextFacetLink.serializer(), element)
            )
            else -> PlaceStreamRichtextFacetFeaturesUnion.Unexpected(element)
        }
    }
}

@Serializable
data class PlaceStreamRichtextFacet(
    @SerialName("index")
    val index: AppBskyRichtextFacetByteSlice,    @SerialName("features")
    val features: List<PlaceStreamRichtextFacetFeaturesUnion>)
