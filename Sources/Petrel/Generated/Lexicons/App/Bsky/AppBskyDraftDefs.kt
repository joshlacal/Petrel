// Lexicon: 1, ID: app.bsky.draft.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyDraftDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.draft.defs"
}

@Serializable(with = AppBskyDraftDefsDraftPostgateEmbeddingRulesUnionSerializer::class)
sealed interface AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion {
    @Serializable
    data class DisableRule(val value: com.atproto.generated.AppBskyFeedPostgateDisableRule) : AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion
}

object AppBskyDraftDefsDraftPostgateEmbeddingRulesUnionSerializer : kotlinx.serialization.KSerializer<AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion.DisableRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedPostgateDisableRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.postgate#disableRule")
                })
            }
            is AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.postgate#disableRule" -> AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion.DisableRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedPostgateDisableRule.serializer(), element)
            )
            else -> AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyDraftDefsDraftThreadgateAllowUnionSerializer::class)
sealed interface AppBskyDraftDefsDraftThreadgateAllowUnion {
    @Serializable
    data class MentionRule(val value: com.atproto.generated.AppBskyFeedThreadgateMentionRule) : AppBskyDraftDefsDraftThreadgateAllowUnion

    @Serializable
    data class FollowerRule(val value: com.atproto.generated.AppBskyFeedThreadgateFollowerRule) : AppBskyDraftDefsDraftThreadgateAllowUnion

    @Serializable
    data class FollowingRule(val value: com.atproto.generated.AppBskyFeedThreadgateFollowingRule) : AppBskyDraftDefsDraftThreadgateAllowUnion

    @Serializable
    data class ListRule(val value: com.atproto.generated.AppBskyFeedThreadgateListRule) : AppBskyDraftDefsDraftThreadgateAllowUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyDraftDefsDraftThreadgateAllowUnion
}

object AppBskyDraftDefsDraftThreadgateAllowUnionSerializer : kotlinx.serialization.KSerializer<AppBskyDraftDefsDraftThreadgateAllowUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyDraftDefsDraftThreadgateAllowUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyDraftDefsDraftThreadgateAllowUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyDraftDefsDraftThreadgateAllowUnion.MentionRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateMentionRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#mentionRule")
                })
            }
            is AppBskyDraftDefsDraftThreadgateAllowUnion.FollowerRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowerRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#followerRule")
                })
            }
            is AppBskyDraftDefsDraftThreadgateAllowUnion.FollowingRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowingRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#followingRule")
                })
            }
            is AppBskyDraftDefsDraftThreadgateAllowUnion.ListRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateListRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#listRule")
                })
            }
            is AppBskyDraftDefsDraftThreadgateAllowUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyDraftDefsDraftThreadgateAllowUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.threadgate#mentionRule" -> AppBskyDraftDefsDraftThreadgateAllowUnion.MentionRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateMentionRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#followerRule" -> AppBskyDraftDefsDraftThreadgateAllowUnion.FollowerRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowerRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#followingRule" -> AppBskyDraftDefsDraftThreadgateAllowUnion.FollowingRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowingRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#listRule" -> AppBskyDraftDefsDraftThreadgateAllowUnion.ListRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateListRule.serializer(), element)
            )
            else -> AppBskyDraftDefsDraftThreadgateAllowUnion.Unexpected(element)
        }
    }
}

@Serializable(with = AppBskyDraftDefsDraftPostLabelsUnionSerializer::class)
sealed interface AppBskyDraftDefsDraftPostLabelsUnion {
    @Serializable
    data class SelfLabels(val value: com.atproto.generated.ComAtprotoLabelDefsSelfLabels) : AppBskyDraftDefsDraftPostLabelsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyDraftDefsDraftPostLabelsUnion
}

object AppBskyDraftDefsDraftPostLabelsUnionSerializer : kotlinx.serialization.KSerializer<AppBskyDraftDefsDraftPostLabelsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyDraftDefsDraftPostLabelsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyDraftDefsDraftPostLabelsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyDraftDefsDraftPostLabelsUnion.SelfLabels -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("com.atproto.label.defs#selfLabels")
                })
            }
            is AppBskyDraftDefsDraftPostLabelsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyDraftDefsDraftPostLabelsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "com.atproto.label.defs#selfLabels" -> AppBskyDraftDefsDraftPostLabelsUnion.SelfLabels(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.ComAtprotoLabelDefsSelfLabels.serializer(), element)
            )
            else -> AppBskyDraftDefsDraftPostLabelsUnion.Unexpected(element)
        }
    }
}

    /**
     * A draft with an identifier, used to store drafts in private storage (stash).
     */
    @Serializable
    data class AppBskyDraftDefsDraftWithId(
/** A TID to be used as a draft identifier. */        @SerialName("id")
        val id: String,        @SerialName("draft")
        val draft: AppBskyDraftDefsDraft    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftWithId"
        }
    }

    /**
     * A draft containing an array of draft posts.
     */
    @Serializable
    data class AppBskyDraftDefsDraft(
/** UUIDv4 identifier of the device that created this draft. */        @SerialName("deviceId")
        val deviceId: String? = null,/** The device and/or platform on which the draft was created. */        @SerialName("deviceName")
        val deviceName: String? = null,/** Array of draft posts that compose this draft. */        @SerialName("posts")
        val posts: List<AppBskyDraftDefsDraftPost>,/** Indicates human language of posts primary text content. */        @SerialName("langs")
        val langs: List<Language>? = null,/** Embedding rules for the postgates to be created when this draft is published. */        @SerialName("postgateEmbeddingRules")
        val postgateEmbeddingRules: List<AppBskyDraftDefsDraftPostgateEmbeddingRulesUnion>? = null,/** Allow-rules for the threadgate to be created when this draft is published. */        @SerialName("threadgateAllow")
        val threadgateAllow: List<AppBskyDraftDefsDraftThreadgateAllowUnion>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraft"
        }
    }

    /**
     * One of the posts that compose a draft.
     */
    @Serializable
    data class AppBskyDraftDefsDraftPost(
/** The primary post content. */        @SerialName("text")
        val text: String,/** Self-label values for this post. Effectively content warnings. */        @SerialName("labels")
        val labels: AppBskyDraftDefsDraftPostLabelsUnion? = null,        @SerialName("embedImages")
        val embedImages: List<AppBskyDraftDefsDraftEmbedImage>? = null,        @SerialName("embedVideos")
        val embedVideos: List<AppBskyDraftDefsDraftEmbedVideo>? = null,        @SerialName("embedExternals")
        val embedExternals: List<AppBskyDraftDefsDraftEmbedExternal>? = null,        @SerialName("embedRecords")
        val embedRecords: List<AppBskyDraftDefsDraftEmbedRecord>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftPost"
        }
    }

    /**
     * View to present drafts data to users.
     */
    @Serializable
    data class AppBskyDraftDefsDraftView(
/** A TID to be used as a draft identifier. */        @SerialName("id")
        val id: String,        @SerialName("draft")
        val draft: AppBskyDraftDefsDraft,/** The time the draft was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** The time the draft was last updated. */        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftView"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedLocalRef(
/** Local, on-device ref to file to be embedded. Embeds are currently device-bound for drafts. */        @SerialName("path")
        val path: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedLocalRef"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedCaption(
        @SerialName("lang")
        val lang: Language,        @SerialName("content")
        val content: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedCaption"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedImage(
        @SerialName("localRef")
        val localRef: AppBskyDraftDefsDraftEmbedLocalRef,        @SerialName("alt")
        val alt: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedImage"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedVideo(
        @SerialName("localRef")
        val localRef: AppBskyDraftDefsDraftEmbedLocalRef,        @SerialName("alt")
        val alt: String? = null,        @SerialName("captions")
        val captions: List<AppBskyDraftDefsDraftEmbedCaption>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedVideo"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedExternal(
        @SerialName("uri")
        val uri: URI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedExternal"
        }
    }

    @Serializable
    data class AppBskyDraftDefsDraftEmbedRecord(
        @SerialName("record")
        val record: ComAtprotoRepoStrongRef    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyDraftDefsDraftEmbedRecord"
        }
    }
