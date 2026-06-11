// Lexicon: 1, ID: app.bsky.feed.threadgate
// Record defining interaction gating rules for a thread (aka, reply controls). The record key (rkey) of the threadgate record must match the record key of the thread's root post, and that record must be in the same repository.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedThreadgateDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.threadgate"
}

@Serializable(with = AppBskyFeedThreadgateAllowUnionSerializer::class)
sealed interface AppBskyFeedThreadgateAllowUnion {
    @Serializable
    data class MentionRule(val value: blue.catbird.petrel.generated.AppBskyFeedThreadgateMentionRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    data class FollowerRule(val value: blue.catbird.petrel.generated.AppBskyFeedThreadgateFollowerRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    data class FollowingRule(val value: blue.catbird.petrel.generated.AppBskyFeedThreadgateFollowingRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    data class ListRule(val value: blue.catbird.petrel.generated.AppBskyFeedThreadgateListRule) : AppBskyFeedThreadgateAllowUnion

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
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyFeedThreadgateMentionRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#mentionRule")
                })
            }
            is AppBskyFeedThreadgateAllowUnion.FollowerRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyFeedThreadgateFollowerRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#followerRule")
                })
            }
            is AppBskyFeedThreadgateAllowUnion.FollowingRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyFeedThreadgateFollowingRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#followingRule")
                })
            }
            is AppBskyFeedThreadgateAllowUnion.ListRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(blue.catbird.petrel.generated.AppBskyFeedThreadgateListRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.threadgate#listRule")
                })
            }
            is AppBskyFeedThreadgateAllowUnion.Unexpected -> value.value
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

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedThreadgateAllowUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.threadgate#mentionRule" -> AppBskyFeedThreadgateAllowUnion.MentionRule(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyFeedThreadgateMentionRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#followerRule" -> AppBskyFeedThreadgateAllowUnion.FollowerRule(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyFeedThreadgateFollowerRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#followingRule" -> AppBskyFeedThreadgateAllowUnion.FollowingRule(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyFeedThreadgateFollowingRule.serializer(), element)
            )
            "app.bsky.feed.threadgate#listRule" -> AppBskyFeedThreadgateAllowUnion.ListRule(
                jsonDecoder.json.decodeFromJsonElement(blue.catbird.petrel.generated.AppBskyFeedThreadgateListRule.serializer(), element)
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
