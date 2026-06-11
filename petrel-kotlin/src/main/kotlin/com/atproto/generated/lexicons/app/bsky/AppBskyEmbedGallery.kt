// Lexicon: 1, ID: app.bsky.embed.gallery
// An assortment of media embedded in a Bluesky record (eg, a post).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyEmbedGalleryDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.gallery"
}

@Serializable(with = AppBskyEmbedGalleryViewItemsUnionSerializer::class)
sealed interface AppBskyEmbedGalleryViewItemsUnion {
    @Serializable
    data class ViewImage(val value: com.atproto.generated.AppBskyEmbedGalleryViewImage) : AppBskyEmbedGalleryViewItemsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyEmbedGalleryViewItemsUnion
}

object AppBskyEmbedGalleryViewItemsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyEmbedGalleryViewItemsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyEmbedGalleryViewItemsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyEmbedGalleryViewItemsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyEmbedGalleryViewItemsUnion.ViewImage -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedGalleryViewImage.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.gallery#viewImage")
                })
            }
            is AppBskyEmbedGalleryViewItemsUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyEmbedGalleryViewItemsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.gallery#viewImage" -> AppBskyEmbedGalleryViewItemsUnion.ViewImage(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedGalleryViewImage.serializer(), element)
            )
            else -> AppBskyEmbedGalleryViewItemsUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyEmbedGalleryItemsUnionSerializer::class)
sealed interface AppBskyEmbedGalleryItemsUnion {
    @Serializable
    data class Image(val value: com.atproto.generated.AppBskyEmbedGalleryImage) : AppBskyEmbedGalleryItemsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyEmbedGalleryItemsUnion
}

object AppBskyEmbedGalleryItemsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyEmbedGalleryItemsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyEmbedGalleryItemsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyEmbedGalleryItemsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyEmbedGalleryItemsUnion.Image -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedGalleryImage.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.gallery#image")
                })
            }
            is AppBskyEmbedGalleryItemsUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyEmbedGalleryItemsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.gallery#image" -> AppBskyEmbedGalleryItemsUnion.Image(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedGalleryImage.serializer(), element)
            )
            else -> AppBskyEmbedGalleryItemsUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class AppBskyEmbedGalleryImage(
        @SerialName("image")
        val image: Blob,/** Alt text description of the image, for accessibility. */        @SerialName("alt")
        val alt: String,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefsAspectRatio    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedGalleryImage"
        }
    }

    @Serializable
    data class AppBskyEmbedGalleryView(
        @SerialName("items")
        val items: List<AppBskyEmbedGalleryViewItemsUnion>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedGalleryView"
        }
    }

    @Serializable
    data class AppBskyEmbedGalleryViewImage(
/** Fully-qualified URL where a thumbnail of the image can be fetched. For example, CDN location provided by the App View. */        @SerialName("thumbnail")
        val thumbnail: URI,/** Fully-qualified URL where a large version of the image can be fetched. May or may not be the exact original blob. For example, CDN location provided by the App View. */        @SerialName("fullsize")
        val fullsize: URI,/** Alt text description of the image, for accessibility. */        @SerialName("alt")
        val alt: String,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefsAspectRatio    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedGalleryViewImage"
        }
    }

@Serializable
data class AppBskyEmbedGallery(
// The schema-level maxLength of 20 is a future-proof ceiling. Clients should currently enforce a soft limit of 10 items in authoring UIs.    @SerialName("items")
    val items: List<AppBskyEmbedGalleryItemsUnion>)
