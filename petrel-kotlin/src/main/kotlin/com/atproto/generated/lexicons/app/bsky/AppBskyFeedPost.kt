// Lexicon: 1, ID: app.bsky.feed.post
// Record containing a Bluesky post.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedPostDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.post"
}

@Serializable(with = AppBskyFeedPostEmbedUnionSerializer::class)
sealed interface AppBskyFeedPostEmbedUnion {
    @Serializable
    data class Images(val value: com.atproto.generated.AppBskyEmbedImages) : AppBskyFeedPostEmbedUnion

    @Serializable
    data class Video(val value: com.atproto.generated.AppBskyEmbedVideo) : AppBskyFeedPostEmbedUnion

    @Serializable
    data class External(val value: com.atproto.generated.AppBskyEmbedExternal) : AppBskyFeedPostEmbedUnion

    @Serializable
    data class Record(val value: com.atproto.generated.AppBskyEmbedRecord) : AppBskyFeedPostEmbedUnion

    @Serializable
    data class RecordWithMedia(val value: com.atproto.generated.AppBskyEmbedRecordWithMedia) : AppBskyFeedPostEmbedUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedPostEmbedUnion
}

object AppBskyFeedPostEmbedUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedPostEmbedUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedPostEmbedUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedPostEmbedUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedPostEmbedUnion.Images -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedImages.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.images")
                })
            }
            is AppBskyFeedPostEmbedUnion.Video -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedVideo.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.video")
                })
            }
            is AppBskyFeedPostEmbedUnion.External -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedExternal.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external")
                })
            }
            is AppBskyFeedPostEmbedUnion.Record -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecord.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record")
                })
            }
            is AppBskyFeedPostEmbedUnion.RecordWithMedia -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordWithMedia.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.recordWithMedia")
                })
            }
            is AppBskyFeedPostEmbedUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedPostEmbedUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.images" -> AppBskyFeedPostEmbedUnion.Images(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedImages.serializer(), element)
            )
            "app.bsky.embed.video" -> AppBskyFeedPostEmbedUnion.Video(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedVideo.serializer(), element)
            )
            "app.bsky.embed.external" -> AppBskyFeedPostEmbedUnion.External(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedExternal.serializer(), element)
            )
            "app.bsky.embed.record" -> AppBskyFeedPostEmbedUnion.Record(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecord.serializer(), element)
            )
            "app.bsky.embed.recordWithMedia" -> AppBskyFeedPostEmbedUnion.RecordWithMedia(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordWithMedia.serializer(), element)
            )
            else -> AppBskyFeedPostEmbedUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyFeedPostLabelsUnionSerializer::class)
sealed interface AppBskyFeedPostLabelsUnion {
    @Serializable
    data class SelfLabels(val value: com.atproto.generated.ComAtprotoLabelDefsSelfLabels) : AppBskyFeedPostLabelsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedPostLabelsUnion
}

object AppBskyFeedPostLabelsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedPostLabelsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedPostLabelsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedPostLabelsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedPostLabelsUnion.SelfLabels -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.defs#selfLabels")
                })
            }
            is AppBskyFeedPostLabelsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedPostLabelsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.label.defs#selfLabels" -> AppBskyFeedPostLabelsUnion.SelfLabels(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), element)
            )
            else -> AppBskyFeedPostLabelsUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class AppBskyFeedPostReplyRef(
        @SerialName("root")
        val root: ComAtprotoRepoStrongRef,        @SerialName("parent")
        val parent: ComAtprotoRepoStrongRef    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedPostReplyRef"
        }
    }

    /**
     * Deprecated: use facets instead.
     */
    @Serializable
    data class AppBskyFeedPostEntity(
        @SerialName("index")
        val index: AppBskyFeedPostTextSlice,/** Expected values are 'mention' and 'link'. */        @SerialName("type")
        val type: String,        @SerialName("value")
        val value: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedPostEntity"
        }
    }

    /**
     * Deprecated. Use app.bsky.richtext instead -- A text segment. Start is inclusive, end is exclusive. Indices are for utf16-encoded strings.
     */
    @Serializable
    data class AppBskyFeedPostTextSlice(
        @SerialName("start")
        val start: Int,        @SerialName("end")
        val end: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedPostTextSlice"
        }
    }

    /**
     * Record containing a Bluesky post.
     */
    @Serializable
    data class AppBskyFeedPost(
/** The primary post content. May be an empty string, if there are embeds. */        @SerialName("text")
        val text: String,/** DEPRECATED: replaced by app.bsky.richtext.facet. */        @SerialName("entities")
        val entities: List<AppBskyFeedPostEntity>? = null,/** Annotations of text (mentions, URLs, hashtags, etc) */        @SerialName("facets")
        val facets: List<AppBskyRichtextFacet>? = null,        @SerialName("reply")
        val reply: AppBskyFeedPostReplyRef? = null,        @SerialName("embed")
        val embed: AppBskyFeedPostEmbedUnion? = null,/** Indicates human language of post primary text content. */        @SerialName("langs")
        val langs: List<Language>? = null,/** Self-label values for this post. Effectively content warnings. */        @SerialName("labels")
        val labels: AppBskyFeedPostLabelsUnion? = null,/** Additional hashtags, in addition to any included in post text and facets. */        @SerialName("tags")
        val tags: List<String>? = null,/** Client-declared timestamp when this post was originally created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
