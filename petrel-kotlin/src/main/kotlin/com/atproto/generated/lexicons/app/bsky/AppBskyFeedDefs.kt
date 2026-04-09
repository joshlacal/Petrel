// Lexicon: 1, ID: app.bsky.feed.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.defs"
}

@Serializable(with = AppBskyFeedDefsPostViewEmbedUnionSerializer::class)
sealed interface AppBskyFeedDefsPostViewEmbedUnion {
    @Serializable
    data class View(val value: com.atproto.generated.AppBskyEmbedImagesView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    data class AppBskyEmbedVideoView(val value: com.atproto.generated.AppBskyEmbedVideoView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    data class AppBskyEmbedExternalView(val value: com.atproto.generated.AppBskyEmbedExternalView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    data class AppBskyEmbedRecordView(val value: com.atproto.generated.AppBskyEmbedRecordView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    data class AppBskyEmbedRecordWithMediaView(val value: com.atproto.generated.AppBskyEmbedRecordWithMediaView) : AppBskyFeedDefsPostViewEmbedUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsPostViewEmbedUnion
}

object AppBskyFeedDefsPostViewEmbedUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedDefsPostViewEmbedUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedDefsPostViewEmbedUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedDefsPostViewEmbedUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedDefsPostViewEmbedUnion.View -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedImagesView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.images#view")
                })
            }
            is AppBskyFeedDefsPostViewEmbedUnion.AppBskyEmbedVideoView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedVideoView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.video#view")
                })
            }
            is AppBskyFeedDefsPostViewEmbedUnion.AppBskyEmbedExternalView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedExternalView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.external#view")
                })
            }
            is AppBskyFeedDefsPostViewEmbedUnion.AppBskyEmbedRecordView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.record#view")
                })
            }
            is AppBskyFeedDefsPostViewEmbedUnion.AppBskyEmbedRecordWithMediaView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyEmbedRecordWithMediaView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.embed.recordWithMedia#view")
                })
            }
            is AppBskyFeedDefsPostViewEmbedUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedDefsPostViewEmbedUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.embed.images#view" -> AppBskyFeedDefsPostViewEmbedUnion.View(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedImagesView.serializer(), element)
            )
            "app.bsky.embed.video#view" -> AppBskyFeedDefsPostViewEmbedUnion.AppBskyEmbedVideoView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedVideoView.serializer(), element)
            )
            "app.bsky.embed.external#view" -> AppBskyFeedDefsPostViewEmbedUnion.AppBskyEmbedExternalView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedExternalView.serializer(), element)
            )
            "app.bsky.embed.record#view" -> AppBskyFeedDefsPostViewEmbedUnion.AppBskyEmbedRecordView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordView.serializer(), element)
            )
            "app.bsky.embed.recordWithMedia#view" -> AppBskyFeedDefsPostViewEmbedUnion.AppBskyEmbedRecordWithMediaView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyEmbedRecordWithMediaView.serializer(), element)
            )
            else -> AppBskyFeedDefsPostViewEmbedUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyFeedDefsFeedViewPostReasonUnionSerializer::class)
sealed interface AppBskyFeedDefsFeedViewPostReasonUnion {
    @Serializable
    data class ReasonRepost(val value: com.atproto.generated.AppBskyFeedDefsReasonRepost) : AppBskyFeedDefsFeedViewPostReasonUnion

    @Serializable
    data class ReasonPin(val value: com.atproto.generated.AppBskyFeedDefsReasonPin) : AppBskyFeedDefsFeedViewPostReasonUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsFeedViewPostReasonUnion
}

object AppBskyFeedDefsFeedViewPostReasonUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedDefsFeedViewPostReasonUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedDefsFeedViewPostReasonUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedDefsFeedViewPostReasonUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedDefsFeedViewPostReasonUnion.ReasonRepost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsReasonRepost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#reasonRepost")
                })
            }
            is AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsReasonPin.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#reasonPin")
                })
            }
            is AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedDefsFeedViewPostReasonUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.defs#reasonRepost" -> AppBskyFeedDefsFeedViewPostReasonUnion.ReasonRepost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsReasonRepost.serializer(), element)
            )
            "app.bsky.feed.defs#reasonPin" -> AppBskyFeedDefsFeedViewPostReasonUnion.ReasonPin(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsReasonPin.serializer(), element)
            )
            else -> AppBskyFeedDefsFeedViewPostReasonUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyFeedDefsReplyRefRootUnionSerializer::class)
sealed interface AppBskyFeedDefsReplyRefRootUnion {
    @Serializable
    data class PostView(val value: com.atproto.generated.AppBskyFeedDefsPostView) : AppBskyFeedDefsReplyRefRootUnion

    @Serializable
    data class NotFoundPost(val value: com.atproto.generated.AppBskyFeedDefsNotFoundPost) : AppBskyFeedDefsReplyRefRootUnion

    @Serializable
    data class BlockedPost(val value: com.atproto.generated.AppBskyFeedDefsBlockedPost) : AppBskyFeedDefsReplyRefRootUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsReplyRefRootUnion
}

object AppBskyFeedDefsReplyRefRootUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedDefsReplyRefRootUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedDefsReplyRefRootUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedDefsReplyRefRootUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedDefsReplyRefRootUnion.PostView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsPostView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#postView")
                })
            }
            is AppBskyFeedDefsReplyRefRootUnion.NotFoundPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#notFoundPost")
                })
            }
            is AppBskyFeedDefsReplyRefRootUnion.BlockedPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#blockedPost")
                })
            }
            is AppBskyFeedDefsReplyRefRootUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedDefsReplyRefRootUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.defs#postView" -> AppBskyFeedDefsReplyRefRootUnion.PostView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsPostView.serializer(), element)
            )
            "app.bsky.feed.defs#notFoundPost" -> AppBskyFeedDefsReplyRefRootUnion.NotFoundPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), element)
            )
            "app.bsky.feed.defs#blockedPost" -> AppBskyFeedDefsReplyRefRootUnion.BlockedPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), element)
            )
            else -> AppBskyFeedDefsReplyRefRootUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyFeedDefsReplyRefParentUnionSerializer::class)
sealed interface AppBskyFeedDefsReplyRefParentUnion {
    @Serializable
    data class PostView(val value: com.atproto.generated.AppBskyFeedDefsPostView) : AppBskyFeedDefsReplyRefParentUnion

    @Serializable
    data class NotFoundPost(val value: com.atproto.generated.AppBskyFeedDefsNotFoundPost) : AppBskyFeedDefsReplyRefParentUnion

    @Serializable
    data class BlockedPost(val value: com.atproto.generated.AppBskyFeedDefsBlockedPost) : AppBskyFeedDefsReplyRefParentUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsReplyRefParentUnion
}

object AppBskyFeedDefsReplyRefParentUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedDefsReplyRefParentUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedDefsReplyRefParentUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedDefsReplyRefParentUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedDefsReplyRefParentUnion.PostView -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsPostView.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#postView")
                })
            }
            is AppBskyFeedDefsReplyRefParentUnion.NotFoundPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#notFoundPost")
                })
            }
            is AppBskyFeedDefsReplyRefParentUnion.BlockedPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#blockedPost")
                })
            }
            is AppBskyFeedDefsReplyRefParentUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedDefsReplyRefParentUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.defs#postView" -> AppBskyFeedDefsReplyRefParentUnion.PostView(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsPostView.serializer(), element)
            )
            "app.bsky.feed.defs#notFoundPost" -> AppBskyFeedDefsReplyRefParentUnion.NotFoundPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), element)
            )
            "app.bsky.feed.defs#blockedPost" -> AppBskyFeedDefsReplyRefParentUnion.BlockedPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), element)
            )
            else -> AppBskyFeedDefsReplyRefParentUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyFeedDefsThreadViewPostParentUnionSerializer::class)
sealed interface AppBskyFeedDefsThreadViewPostParentUnion {
    @Serializable
    data class ThreadViewPost(val value: com.atproto.generated.AppBskyFeedDefsThreadViewPost) : AppBskyFeedDefsThreadViewPostParentUnion

    @Serializable
    data class NotFoundPost(val value: com.atproto.generated.AppBskyFeedDefsNotFoundPost) : AppBskyFeedDefsThreadViewPostParentUnion

    @Serializable
    data class BlockedPost(val value: com.atproto.generated.AppBskyFeedDefsBlockedPost) : AppBskyFeedDefsThreadViewPostParentUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsThreadViewPostParentUnion
}

object AppBskyFeedDefsThreadViewPostParentUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedDefsThreadViewPostParentUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedDefsThreadViewPostParentUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedDefsThreadViewPostParentUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedDefsThreadViewPostParentUnion.ThreadViewPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsThreadViewPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#threadViewPost")
                })
            }
            is AppBskyFeedDefsThreadViewPostParentUnion.NotFoundPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#notFoundPost")
                })
            }
            is AppBskyFeedDefsThreadViewPostParentUnion.BlockedPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#blockedPost")
                })
            }
            is AppBskyFeedDefsThreadViewPostParentUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedDefsThreadViewPostParentUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.defs#threadViewPost" -> AppBskyFeedDefsThreadViewPostParentUnion.ThreadViewPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsThreadViewPost.serializer(), element)
            )
            "app.bsky.feed.defs#notFoundPost" -> AppBskyFeedDefsThreadViewPostParentUnion.NotFoundPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), element)
            )
            "app.bsky.feed.defs#blockedPost" -> AppBskyFeedDefsThreadViewPostParentUnion.BlockedPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), element)
            )
            else -> AppBskyFeedDefsThreadViewPostParentUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyFeedDefsThreadViewPostRepliesUnionSerializer::class)
sealed interface AppBskyFeedDefsThreadViewPostRepliesUnion {
    @Serializable
    data class ThreadViewPost(val value: com.atproto.generated.AppBskyFeedDefsThreadViewPost) : AppBskyFeedDefsThreadViewPostRepliesUnion

    @Serializable
    data class NotFoundPost(val value: com.atproto.generated.AppBskyFeedDefsNotFoundPost) : AppBskyFeedDefsThreadViewPostRepliesUnion

    @Serializable
    data class BlockedPost(val value: com.atproto.generated.AppBskyFeedDefsBlockedPost) : AppBskyFeedDefsThreadViewPostRepliesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsThreadViewPostRepliesUnion
}

object AppBskyFeedDefsThreadViewPostRepliesUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedDefsThreadViewPostRepliesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedDefsThreadViewPostRepliesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedDefsThreadViewPostRepliesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedDefsThreadViewPostRepliesUnion.ThreadViewPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsThreadViewPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#threadViewPost")
                })
            }
            is AppBskyFeedDefsThreadViewPostRepliesUnion.NotFoundPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#notFoundPost")
                })
            }
            is AppBskyFeedDefsThreadViewPostRepliesUnion.BlockedPost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#blockedPost")
                })
            }
            is AppBskyFeedDefsThreadViewPostRepliesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedDefsThreadViewPostRepliesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.defs#threadViewPost" -> AppBskyFeedDefsThreadViewPostRepliesUnion.ThreadViewPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsThreadViewPost.serializer(), element)
            )
            "app.bsky.feed.defs#notFoundPost" -> AppBskyFeedDefsThreadViewPostRepliesUnion.NotFoundPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsNotFoundPost.serializer(), element)
            )
            "app.bsky.feed.defs#blockedPost" -> AppBskyFeedDefsThreadViewPostRepliesUnion.BlockedPost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsBlockedPost.serializer(), element)
            )
            else -> AppBskyFeedDefsThreadViewPostRepliesUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyFeedDefsSkeletonFeedPostReasonUnionSerializer::class)
sealed interface AppBskyFeedDefsSkeletonFeedPostReasonUnion {
    @Serializable
    data class SkeletonReasonRepost(val value: com.atproto.generated.AppBskyFeedDefsSkeletonReasonRepost) : AppBskyFeedDefsSkeletonFeedPostReasonUnion

    @Serializable
    data class SkeletonReasonPin(val value: com.atproto.generated.AppBskyFeedDefsSkeletonReasonPin) : AppBskyFeedDefsSkeletonFeedPostReasonUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedDefsSkeletonFeedPostReasonUnion
}

object AppBskyFeedDefsSkeletonFeedPostReasonUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedDefsSkeletonFeedPostReasonUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedDefsSkeletonFeedPostReasonUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedDefsSkeletonFeedPostReasonUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedDefsSkeletonFeedPostReasonUnion.SkeletonReasonRepost -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsSkeletonReasonRepost.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#skeletonReasonRepost")
                })
            }
            is AppBskyFeedDefsSkeletonFeedPostReasonUnion.SkeletonReasonPin -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedDefsSkeletonReasonPin.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.defs#skeletonReasonPin")
                })
            }
            is AppBskyFeedDefsSkeletonFeedPostReasonUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedDefsSkeletonFeedPostReasonUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.defs#skeletonReasonRepost" -> AppBskyFeedDefsSkeletonFeedPostReasonUnion.SkeletonReasonRepost(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsSkeletonReasonRepost.serializer(), element)
            )
            "app.bsky.feed.defs#skeletonReasonPin" -> AppBskyFeedDefsSkeletonFeedPostReasonUnion.SkeletonReasonPin(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedDefsSkeletonReasonPin.serializer(), element)
            )
            else -> AppBskyFeedDefsSkeletonFeedPostReasonUnion.Unexpected(element)
        }
    }
}

    @Serializable
    data class AppBskyFeedDefsPostView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefsProfileViewBasic,        @SerialName("record")
        val record: JsonElement,        @SerialName("embed")
        val embed: AppBskyFeedDefsPostViewEmbedUnion? = null,        @SerialName("bookmarkCount")
        val bookmarkCount: Int? = null,        @SerialName("replyCount")
        val replyCount: Int? = null,        @SerialName("repostCount")
        val repostCount: Int? = null,        @SerialName("likeCount")
        val likeCount: Int? = null,        @SerialName("quoteCount")
        val quoteCount: Int? = null,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("viewer")
        val viewer: AppBskyFeedDefsViewerState? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("threadgate")
        val threadgate: AppBskyFeedDefsThreadgateView? = null,/** Debug information for internal development */        @SerialName("debug")
        val debug: JsonElement? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsPostView"
        }
    }

    /**
     * Metadata about the requesting account's relationship with the subject content. Only has meaningful content for authed requests.
     */
    @Serializable
    data class AppBskyFeedDefsViewerState(
        @SerialName("repost")
        val repost: ATProtocolURI? = null,        @SerialName("like")
        val like: ATProtocolURI? = null,        @SerialName("bookmarked")
        val bookmarked: Boolean? = null,        @SerialName("threadMuted")
        val threadMuted: Boolean? = null,        @SerialName("replyDisabled")
        val replyDisabled: Boolean? = null,        @SerialName("embeddingDisabled")
        val embeddingDisabled: Boolean? = null,        @SerialName("pinned")
        val pinned: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsViewerState"
        }
    }

    /**
     * Metadata about this post within the context of the thread it is in.
     */
    @Serializable
    data class AppBskyFeedDefsThreadContext(
        @SerialName("rootAuthorLike")
        val rootAuthorLike: ATProtocolURI? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsThreadContext"
        }
    }

    @Serializable
    data class AppBskyFeedDefsFeedViewPost(
        @SerialName("post")
        val post: AppBskyFeedDefsPostView,        @SerialName("reply")
        val reply: AppBskyFeedDefsReplyRef? = null,        @SerialName("reason")
        val reason: AppBskyFeedDefsFeedViewPostReasonUnion? = null,/** Context provided by feed generator that may be passed back alongside interactions. */        @SerialName("feedContext")
        val feedContext: String? = null,/** Unique identifier per request that may be passed back alongside interactions. */        @SerialName("reqId")
        val reqId: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsFeedViewPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsReplyRef(
        @SerialName("root")
        val root: AppBskyFeedDefsReplyRefRootUnion,        @SerialName("parent")
        val parent: AppBskyFeedDefsReplyRefParentUnion,/** When parent is a reply to another post, this is the author of that post. */        @SerialName("grandparentAuthor")
        val grandparentAuthor: AppBskyActorDefsProfileViewBasic? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsReplyRef"
        }
    }

    @Serializable
    data class AppBskyFeedDefsReasonRepost(
        @SerialName("by")
        val `by`: AppBskyActorDefsProfileViewBasic,        @SerialName("uri")
        val uri: ATProtocolURI? = null,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsReasonRepost"
        }
    }

    @Serializable
    class AppBskyFeedDefsReasonPin {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsReasonPin"
        }
    }

    @Serializable
    data class AppBskyFeedDefsThreadViewPost(
        @SerialName("post")
        val post: AppBskyFeedDefsPostView,        @SerialName("parent")
        val parent: AppBskyFeedDefsThreadViewPostParentUnion? = null,        @SerialName("replies")
        val replies: List<AppBskyFeedDefsThreadViewPostRepliesUnion>? = null,        @SerialName("threadContext")
        val threadContext: AppBskyFeedDefsThreadContext? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsThreadViewPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsNotFoundPost(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("notFound")
        val notFound: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsNotFoundPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsBlockedPost(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("blocked")
        val blocked: Boolean,        @SerialName("author")
        val author: AppBskyFeedDefsBlockedAuthor    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsBlockedPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsBlockedAuthor(
        @SerialName("did")
        val did: DID,        @SerialName("viewer")
        val viewer: AppBskyActorDefsViewerState? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsBlockedAuthor"
        }
    }

    @Serializable
    data class AppBskyFeedDefsGeneratorView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("did")
        val did: DID,        @SerialName("creator")
        val creator: AppBskyActorDefsProfileView,        @SerialName("displayName")
        val displayName: String,        @SerialName("description")
        val description: String? = null,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>? = null,        @SerialName("avatar")
        val avatar: URI? = null,        @SerialName("likeCount")
        val likeCount: Int? = null,        @SerialName("acceptsInteractions")
        val acceptsInteractions: Boolean? = null,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>? = null,        @SerialName("viewer")
        val viewer: AppBskyFeedDefsGeneratorViewerState? = null,        @SerialName("contentMode")
        val contentMode: String? = null,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsGeneratorView"
        }
    }

    @Serializable
    data class AppBskyFeedDefsGeneratorViewerState(
        @SerialName("like")
        val like: ATProtocolURI? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsGeneratorViewerState"
        }
    }

    @Serializable
    data class AppBskyFeedDefsSkeletonFeedPost(
        @SerialName("post")
        val post: ATProtocolURI,        @SerialName("reason")
        val reason: AppBskyFeedDefsSkeletonFeedPostReasonUnion? = null,/** Context that will be passed through to client and may be passed to feed generator back alongside interactions. */        @SerialName("feedContext")
        val feedContext: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsSkeletonFeedPost"
        }
    }

    @Serializable
    data class AppBskyFeedDefsSkeletonReasonRepost(
        @SerialName("repost")
        val repost: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsSkeletonReasonRepost"
        }
    }

    @Serializable
    class AppBskyFeedDefsSkeletonReasonPin {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsSkeletonReasonPin"
        }
    }

    @Serializable
    data class AppBskyFeedDefsThreadgateView(
        @SerialName("uri")
        val uri: ATProtocolURI? = null,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("record")
        val record: JsonElement? = null,        @SerialName("lists")
        val lists: List<AppBskyGraphDefsListViewBasic>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsThreadgateView"
        }
    }

    @Serializable
    data class AppBskyFeedDefsInteraction(
        @SerialName("item")
        val item: ATProtocolURI? = null,        @SerialName("event")
        val event: String? = null,/** Context on a feed item that was originally supplied by the feed generator on getFeedSkeleton. */        @SerialName("feedContext")
        val feedContext: String? = null,/** Unique identifier per request that may be passed back alongside interactions. */        @SerialName("reqId")
        val reqId: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDefsInteraction"
        }
    }
