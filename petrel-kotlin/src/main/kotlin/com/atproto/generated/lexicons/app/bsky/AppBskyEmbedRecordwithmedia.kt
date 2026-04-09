// Lexicon: 1, ID: app.bsky.embed.recordWithMedia
// A representation of a record embedded in a Bluesky record (eg, a post), alongside other compatible embeds. For example, a quote post and image, or a quote post and external URL card.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyEmbedRecordWithMediaDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.recordWithMedia"
}

@Serializable(with = AppBskyEmbedRecordWithMediaViewMediaUnionSerializer::class)
sealed interface AppBskyEmbedRecordWithMediaViewMediaUnion {
    @Serializable
    data class View(val value: com.atproto.generated.AppBskyEmbedImagesView) : AppBskyEmbedRecordWithMediaViewMediaUnion

    @Serializable
    data class AppBskyEmbedVideoView(val value: com.atproto.generated.AppBskyEmbedVideoView) : AppBskyEmbedRecordWithMediaViewMediaUnion

    @Serializable
    data class AppBskyEmbedExternalView(val value: com.atproto.generated.AppBskyEmbedExternalView) : AppBskyEmbedRecordWithMediaViewMediaUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedImagesView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.images#view")
                })
            }
            is AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedVideoView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedVideoView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.video#view")
                })
            }
            is AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedExternalView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedExternalView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external#view")
                })
            }
            is AppBskyEmbedRecordWithMediaViewMediaUnion.Unexpected -> value.value
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
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedImagesView.serializer(), element)
            )
            "app.bsky.embed.video#view" -> AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedVideoView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedVideoView.serializer(), element)
            )
            "app.bsky.embed.external#view" -> AppBskyEmbedRecordWithMediaViewMediaUnion.AppBskyEmbedExternalView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedExternalView.serializer(), element)
            )
            else -> AppBskyEmbedRecordWithMediaViewMediaUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyEmbedRecordWithMediaMediaUnionSerializer::class)
sealed interface AppBskyEmbedRecordWithMediaMediaUnion {
    @Serializable
    data class Images(val value: com.atproto.generated.AppBskyEmbedImages) : AppBskyEmbedRecordWithMediaMediaUnion

    @Serializable
    data class Video(val value: com.atproto.generated.AppBskyEmbedVideo) : AppBskyEmbedRecordWithMediaMediaUnion

    @Serializable
    data class External(val value: com.atproto.generated.AppBskyEmbedExternal) : AppBskyEmbedRecordWithMediaMediaUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedImages.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.images")
                })
            }
            is AppBskyEmbedRecordWithMediaMediaUnion.Video -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedVideo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.video")
                })
            }
            is AppBskyEmbedRecordWithMediaMediaUnion.External -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedExternal.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external")
                })
            }
            is AppBskyEmbedRecordWithMediaMediaUnion.Unexpected -> value.value
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
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedImages.serializer(), element)
            )
            "app.bsky.embed.video" -> AppBskyEmbedRecordWithMediaMediaUnion.Video(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedVideo.serializer(), element)
            )
            "app.bsky.embed.external" -> AppBskyEmbedRecordWithMediaMediaUnion.External(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedExternal.serializer(), element)
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
