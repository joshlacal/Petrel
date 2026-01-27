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

@Serializable
sealed interface AppBskyFeedPostEmbedUnion {
    @Serializable
    @SerialName("app.bsky.feed.post#AppBskyEmbedImages")
    data class AppBskyEmbedImages(val value: AppBskyEmbedImages) : AppBskyFeedPostEmbedUnion

    @Serializable
    @SerialName("app.bsky.feed.post#AppBskyEmbedVideo")
    data class AppBskyEmbedVideo(val value: AppBskyEmbedVideo) : AppBskyFeedPostEmbedUnion

    @Serializable
    @SerialName("app.bsky.feed.post#AppBskyEmbedExternal")
    data class AppBskyEmbedExternal(val value: AppBskyEmbedExternal) : AppBskyFeedPostEmbedUnion

    @Serializable
    @SerialName("app.bsky.feed.post#AppBskyEmbedRecord")
    data class AppBskyEmbedRecord(val value: AppBskyEmbedRecord) : AppBskyFeedPostEmbedUnion

    @Serializable
    @SerialName("app.bsky.feed.post#AppBskyEmbedRecordWithMedia")
    data class AppBskyEmbedRecordWithMedia(val value: AppBskyEmbedRecordWithMedia) : AppBskyFeedPostEmbedUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedPostEmbedUnion
}

@Serializable
sealed interface AppBskyFeedPostLabelsUnion {
    @Serializable
    @SerialName("app.bsky.feed.post#ComAtprotoLabelDefsSelfLabels")
    data class ComAtprotoLabelDefsSelfLabels(val value: ComAtprotoLabelDefsSelfLabels) : AppBskyFeedPostLabelsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyFeedPostLabelsUnion
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
