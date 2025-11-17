// Lexicon: 1, ID: app.bsky.feed.threadgate
// Record defining interaction gating rules for a thread (aka, reply controls). The record key (rkey) of the threadgate record must match the record key of the thread's root post, and that record must be in the same repository.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface AppBskyFeedThreadgateAllowUnion {
    @Serializable
    @SerialName("app.bsky.feed.threadgate#Mentionrule")
    data class Mentionrule(val value: Mentionrule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    @SerialName("app.bsky.feed.threadgate#Followerrule")
    data class Followerrule(val value: Followerrule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    @SerialName("app.bsky.feed.threadgate#Followingrule")
    data class Followingrule(val value: Followingrule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    @SerialName("app.bsky.feed.threadgate#Listrule")
    data class Listrule(val value: Listrule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedThreadgateAllowUnion
}

object AppBskyFeedThreadgate {
    const val TYPE_IDENTIFIER = "app.bsky.feed.threadgate"

        /**
     * Record defining interaction gating rules for a thread (aka, reply controls). The record key (rkey) of the threadgate record must match the record key of the thread's root post, and that record must be in the same repository.
     */
    @Serializable
    data class Record(
/** Reference (AT-URI) to the post record. */        @SerialName("post")
        val post: ATProtocolURI,/** List of rules defining who can reply to this post. If value is an empty array, no one can reply. If value is undefined, anyone can reply. */        @SerialName("allow")
        val allow: List<AppBskyFeedThreadgateAllowUnion>? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** List of hidden reply URIs. */        @SerialName("hiddenReplies")
        val hiddenReplies: List<ATProtocolURI>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

        /**
     * Allow replies from actors mentioned in your post.
     */
    @Serializable
    data class Mentionrule(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#mentionrule"
        }
    }

    /**
     * Allow replies from actors who follow you.
     */
    @Serializable
    data class Followerrule(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#followerrule"
        }
    }

    /**
     * Allow replies from actors you follow.
     */
    @Serializable
    data class Followingrule(
    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#followingrule"
        }
    }

    /**
     * Allow replies from actors on a list.
     */
    @Serializable
    data class Listrule(
        @SerialName("list")
        val list: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#listrule"
        }
    }

}
