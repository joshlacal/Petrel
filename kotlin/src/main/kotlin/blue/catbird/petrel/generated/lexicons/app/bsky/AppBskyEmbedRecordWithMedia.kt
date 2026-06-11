// Lexicon: 1, ID: app.bsky.embed.recordWithMedia
// A representation of a record embedded in a Bluesky record (eg, a post), alongside other compatible embeds. For example, a quote post and image, or a quote post and external URL card.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyEmbedRecordWithMediaDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.recordWithMedia"
}

@Serializable(with = AppBskyEmbedRecordWithMediaViewMediaUnionSerializer::class)
sealed interface AppBskyEmbedRecordWithMediaViewMediaUnion {
    @Serializable
    data class View(val value: blue.catbird.petrel.generated.AppBskyEmbedImagesView) : AppBskyEmbedRecordWithMediaViewMediaUnion

    @Serializable
    data class AppBskyEmbedVideoView(val value: blue.catbird.petrel.generated.AppBskyEmbedVideoView) : AppBskyEmbedRecordWithMediaViewMediaUnion

    @Serializable
    data class AppBskyEmbedGalleryView(val value: blue.catbird.petrel.generated.AppBskyEmbedGalleryView) : AppBskyEmbedRecordWithMediaViewMediaUnion

    @Serializable
    data class AppBskyEmbedExternalView(val value: blue.catbird.petrel.generated.AppBskyEmbedExternalView) : AppBskyEmbedRecordWithMediaViewMediaUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyEmbedRecordWithMediaViewMediaUnion
}

object AppBskyEmbedRecordWithMediaViewMediaUnionSerializer : kotlinx.serialization.KSerializer<AppBskyEmbedRecordWithMediaViewMediaUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyEmbedRecordWithMediaViewMediaUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyEmbedRecordWithMediaViewMediaUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyEmbedRecordWithMediaViewMediaUnion.View -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedImagesView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.images#view")
                })
            }
            is AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedVideoView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedVideoView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.video#view")
                })
            }
            is AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedGalleryView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedGalleryView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.gallery#view")
                })
            }
            is AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedExternalView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedExternalView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external#view")
                })
            }
            is AppBskyEmbedRecordWithMediaViewMediaUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyEmbedRecordWithMediaViewMediaUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.images#view" -> AppBskyEmbedRecordWithMediaViewMediaUnion.View(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedImagesView.serializer(), element)
            )
            "app.bsky.embed.video#view" -> AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedVideoView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedVideoView.serializer(), element)
            )
            "app.bsky.embed.gallery#view" -> AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedGalleryView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedGalleryView.serializer(), element)
            )
            "app.bsky.embed.external#view" -> AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedExternalView(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedExternalView.serializer(), element)
            )
            else -> AppBskyEmbedRecordWithMediaViewMediaUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyEmbedRecordWithMediaMediaUnionSerializer::class)
sealed interface AppBskyEmbedRecordWithMediaMediaUnion {
    @Serializable
    data class Images(val value: blue.catbird.petrel.generated.AppBskyEmbedImages) : AppBskyEmbedRecordWithMediaMediaUnion

    @Serializable
    data class Video(val value: blue.catbird.petrel.generated.AppBskyEmbedVideo) : AppBskyEmbedRecordWithMediaMediaUnion

    @Serializable
    data class Gallery(val value: blue.catbird.petrel.generated.AppBskyEmbedGallery) : AppBskyEmbedRecordWithMediaMediaUnion

    @Serializable
    data class External(val value: blue.catbird.petrel.generated.AppBskyEmbedExternal) : AppBskyEmbedRecordWithMediaMediaUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyEmbedRecordWithMediaMediaUnion
}

object AppBskyEmbedRecordWithMediaMediaUnionSerializer : kotlinx.serialization.KSerializer<AppBskyEmbedRecordWithMediaMediaUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyEmbedRecordWithMediaMediaUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyEmbedRecordWithMediaMediaUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyEmbedRecordWithMediaMediaUnion.Images -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedImages.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.images")
                })
            }
            is AppBskyEmbedRecordWithMediaMediaUnion.Video -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedVideo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.video")
                })
            }
            is AppBskyEmbedRecordWithMediaMediaUnion.Gallery -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedGallery.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.gallery")
                })
            }
            is AppBskyEmbedRecordWithMediaMediaUnion.External -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyEmbedExternal.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external")
                })
            }
            is AppBskyEmbedRecordWithMediaMediaUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyEmbedRecordWithMediaMediaUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.images" -> AppBskyEmbedRecordWithMediaMediaUnion.Images(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedImages.serializer(), element)
            )
            "app.bsky.embed.video" -> AppBskyEmbedRecordWithMediaMediaUnion.Video(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedVideo.serializer(), element)
            )
            "app.bsky.embed.gallery" -> AppBskyEmbedRecordWithMediaMediaUnion.Gallery(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedGallery.serializer(), element)
            )
            "app.bsky.embed.external" -> AppBskyEmbedRecordWithMediaMediaUnion.External(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyEmbedExternal.serializer(), element)
            )
            else -> AppBskyEmbedRecordWithMediaMediaUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class AppBskyEmbedRecordWithMediaView(
        @SerialName("record")
        val record: AppBskyEmbedRecordView,        @SerialName("media")
        val media: AppBskyEmbedRecordWithMediaViewMediaUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordWithMediaView"
        }
    }

@Serializable
data class AppBskyEmbedRecordWithMedia(
    @SerialName("record")
    val record: AppBskyEmbedRecord,    @SerialName("media")
    val media: AppBskyEmbedRecordWithMediaMediaUnion)
