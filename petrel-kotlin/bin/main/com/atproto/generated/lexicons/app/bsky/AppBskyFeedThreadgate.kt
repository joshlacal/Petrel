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

@Serializable
sealed interface AppBskyFeedThreadgateAllowUnion {
    @Serializable
    @SerialName("app.bsky.feed.threadgate#AppBskyFeedThreadgateMentionRule")
    data class AppBskyFeedThreadgateMentionRule(val value: AppBskyFeedThreadgateMentionRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    @SerialName("app.bsky.feed.threadgate#AppBskyFeedThreadgateFollowerRule")
    data class AppBskyFeedThreadgateFollowerRule(val value: AppBskyFeedThreadgateFollowerRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    @SerialName("app.bsky.feed.threadgate#AppBskyFeedThreadgateFollowingRule")
    data class AppBskyFeedThreadgateFollowingRule(val value: AppBskyFeedThreadgateFollowingRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    @SerialName("app.bsky.feed.threadgate#AppBskyFeedThreadgateListRule")
    data class AppBskyFeedThreadgateListRule(val value: AppBskyFeedThreadgateListRule) : AppBskyFeedThreadgateAllowUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedThreadgateAllowUnion
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
