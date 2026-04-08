// Lexicon: 1, ID: app.bsky.feed.threadgate
// Record defining interaction gating rules for a thread (aka, reply controls). The record key (rkey) of the threadgate record must match the record key of the thread's root post, and that record must be in the same repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedThreadgateDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.threadgate"
}

@Serializable(with = AppBskyFeedThreadgateAllowUnionSerializer::class)
sealed interface AppBskyFeedThreadgateAllowUnion {
    @Serializable
    data class MentionRule(val value: com.atproto.generated.AppBskyFeedThreadgateMentionRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    data class FollowerRule(val value: com.atproto.generated.AppBskyFeedThreadgateFollowerRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    data class FollowingRule(val value: com.atproto.generated.AppBskyFeedThreadgateFollowingRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    data class ListRule(val value: com.atproto.generated.AppBskyFeedThreadgateListRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedThreadgateAllowUnion
}

object AppBskyFeedThreadgateAllowUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedThreadgateAllowUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedThreadgateAllowUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedThreadgateAllowUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedThreadgateAllowUnion.MentionRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateMentionRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#mentionRule")
                })
            }
            is AppBskyFeedThreadgateAllowUnion.FollowerRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowerRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#followerRule")
                })
            }
            is AppBskyFeedThreadgateAllowUnion.FollowingRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowingRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#followingRule")
                })
            }
            is AppBskyFeedThreadgateAllowUnion.ListRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedThreadgateListRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#listRule")
                })
            }
            is AppBskyFeedThreadgateAllowUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedThreadgateAllowUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.threadgate#mentionRule" -> AppBskyFeedThreadgateAllowUnion.MentionRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateMentionRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#followerRule" -> AppBskyFeedThreadgateAllowUnion.FollowerRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowerRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#followingRule" -> AppBskyFeedThreadgateAllowUnion.FollowingRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateFollowingRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#listRule" -> AppBskyFeedThreadgateAllowUnion.ListRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedThreadgateListRule.serializer(), element)
            )
            else -> AppBskyFeedThreadgateAllowUnion.Unexpected(element)
        }
    }
}

    /**
     * Allow replies from actors mentioned in your post.
     */
    @Serializable
    class AppBskyFeedThreadgateMentionRule {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedThreadgateMentionRule"
        }
    }

    /**
     * Allow replies from actors who follow you.
     */
    @Serializable
    class AppBskyFeedThreadgateFollowerRule {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedThreadgateFollowerRule"
        }
    }

    /**
     * Allow replies from actors you follow.
     */
    @Serializable
    class AppBskyFeedThreadgateFollowingRule {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedThreadgateFollowingRule"
        }
    }

    /**
     * Allow replies from actors on a list.
     */
    @Serializable
    data class AppBskyFeedThreadgateListRule(
        @SerialName("list")
        val list: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedThreadgateListRule"
        }
    }

    /**
     * Record defining interaction gating rules for a thread (aka, reply controls). The record key (rkey) of the threadgate record must match the record key of the thread's root post, and that record must be in the same repository.
     */
    @Serializable
    data class AppBskyFeedThreadgate(
/** Reference (AT-URI) to the post record. */        @SerialName("post")
        val post: ATProtocolURI,/** List of rules defining who can reply to this post. If value is an empty array, no one can reply. If value is undefined, anyone can reply. */        @SerialName("allow")
        val allow: List<AppBskyFeedThreadgateAllowUnion>? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** List of hidden reply URIs. */        @SerialName("hiddenReplies")
        val hiddenReplies: List<ATProtocolURI>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
