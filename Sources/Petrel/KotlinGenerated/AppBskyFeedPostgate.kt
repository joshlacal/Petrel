// Lexicon: 1, ID: app.bsky.feed.postgate
// Record defining interaction rules for a post. The record key (rkey) of the postgate record must match the record key of the post, and that record must be in the same repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface AppBskyFeedPostgateEmbeddingrulesUnion {
    @Serializable
    @SerialName("app.bsky.feed.postgate#Disablerule")
    data class Disablerule(val value: Disablerule) : AppBskyFeedPostgateEmbeddingrulesUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedPostgateEmbeddingrulesUnion
}

object AppBskyFeedPostgate {
    const val TYPE_IDENTIFIER = "app.bsky.feed.postgate"

        /**
     * Record defining interaction rules for a post. The record key (rkey) of the postgate record must match the record key of the post, and that record must be in the same repository.
     */
    @Serializable
    data class Record(
        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Reference (AT-URI) to the post record. */        @SerialName("post")
        val post: ATProtocolURI,/** List of AT-URIs embedding this post that the author has detached from. */        @SerialName("detachedEmbeddingUris")
        val detachedEmbeddingUris: List<ATProtocolURI>? = null,/** List of rules defining who can embed this post. If value is an empty array or is undefined, no particular rules apply and anyone can embed. */        @SerialName("embeddingRules")
        val embeddingRules: List<AppBskyFeedPostgateEmbeddingrulesUnion>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

        /**
     * Disables embedding of this post.
     */
    @Serializable
    data class Disablerule(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#disablerule"
        }
    }

}
