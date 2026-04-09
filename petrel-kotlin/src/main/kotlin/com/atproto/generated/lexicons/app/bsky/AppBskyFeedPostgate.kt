// Lexicon: 1, ID: app.bsky.feed.postgate
// Record defining interaction rules for a post. The record key (rkey) of the postgate record must match the record key of the post, and that record must be in the same repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedPostgateDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.postgate"
}

@Serializable(with = AppBskyFeedPostgateEmbeddingRulesUnionSerializer::class)
sealed interface AppBskyFeedPostgateEmbeddingRulesUnion {
    @Serializable
    data class DisableRule(val value: com.atproto.generated.AppBskyFeedPostgateDisableRule) : AppBskyFeedPostgateEmbeddingRulesUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : AppBskyFeedPostgateEmbeddingRulesUnion
}

object AppBskyFeedPostgateEmbeddingRulesUnionSerializer : kotlinx.serialization.KSerializer<AppBskyFeedPostgateEmbeddingRulesUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("AppBskyFeedPostgateEmbeddingRulesUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: AppBskyFeedPostgateEmbeddingRulesUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is AppBskyFeedPostgateEmbeddingRulesUnion.DisableRule -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.AppBskyFeedPostgateDisableRule.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("app.bsky.feed.postgate#disableRule")
                })
            }
            is AppBskyFeedPostgateEmbeddingRulesUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): AppBskyFeedPostgateEmbeddingRulesUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "app.bsky.feed.postgate#disableRule" -> AppBskyFeedPostgateEmbeddingRulesUnion.DisableRule(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.AppBskyFeedPostgateDisableRule.serializer(), element)
            )
            else -> AppBskyFeedPostgateEmbeddingRulesUnion.Unexpected(element)
        }
    }
}

    /**
     * Disables embedding of this post.
     */
    @Serializable
    class AppBskyFeedPostgateDisableRule {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedPostgateDisableRule"
        }
    }

    /**
     * Record defining interaction rules for a post. The record key (rkey) of the postgate record must match the record key of the post, and that record must be in the same repository.
     */
    @Serializable
    data class AppBskyFeedPostgate(
        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Reference (AT-URI) to the post record. */        @SerialName("post")
        val post: ATProtocolURI,/** List of AT-URIs embedding this post that the author has detached from. */        @SerialName("detachedEmbeddingUris")
        val detachedEmbeddingUris: List<ATProtocolURI>? = null,/** List of rules defining who can embed this post. If value is an empty array or is undefined, no particular rules apply and anyone can embed. */        @SerialName("embeddingRules")
        val embeddingRules: List<AppBskyFeedPostgateEmbeddingRulesUnion>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
