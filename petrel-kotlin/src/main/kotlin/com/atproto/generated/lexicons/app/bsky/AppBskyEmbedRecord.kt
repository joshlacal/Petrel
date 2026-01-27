// Lexicon: 1, ID: app.bsky.embed.record
// A representation of a record embedded in a Bluesky record (eg, a post). For example, a quote-post, or sharing a feed generator record.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyEmbedRecordDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.record"
}

@Serializable
sealed interface AppBskyEmbedRecordViewRecordUnion {
    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyEmbedRecordViewRecord")
    data class AppBskyEmbedRecordViewRecord(val value: AppBskyEmbedRecordViewRecord) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyEmbedRecordViewNotFound")
    data class AppBskyEmbedRecordViewNotFound(val value: AppBskyEmbedRecordViewNotFound) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyEmbedRecordViewBlocked")
    data class AppBskyEmbedRecordViewBlocked(val value: AppBskyEmbedRecordViewBlocked) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyEmbedRecordViewDetached")
    data class AppBskyEmbedRecordViewDetached(val value: AppBskyEmbedRecordViewDetached) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyFeedDefsGeneratorView")
    data class AppBskyFeedDefsGeneratorView(val value: AppBskyFeedDefsGeneratorView) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyGraphDefsListView")
    data class AppBskyGraphDefsListView(val value: AppBskyGraphDefsListView) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyLabelerDefsLabelerView")
    data class AppBskyLabelerDefsLabelerView(val value: AppBskyLabelerDefsLabelerView) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyGraphDefsStarterPackViewBasic")
    data class AppBskyGraphDefsStarterPackViewBasic(val value: AppBskyGraphDefsStarterPackViewBasic) : AppBskyEmbedRecordViewRecordUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyEmbedRecordViewRecordUnion
}

@Serializable
sealed interface AppBskyEmbedRecordViewRecordEmbedsUnion {
    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyEmbedImagesView")
    data class AppBskyEmbedImagesView(val value: AppBskyEmbedImagesView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyEmbedVideoView")
    data class AppBskyEmbedVideoView(val value: AppBskyEmbedVideoView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyEmbedExternalView")
    data class AppBskyEmbedExternalView(val value: AppBskyEmbedExternalView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyEmbedRecordView")
    data class AppBskyEmbedRecordView(val value: AppBskyEmbedRecordView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    @SerialName("app.bsky.embed.record#AppBskyEmbedRecordWithMediaView")
    data class AppBskyEmbedRecordWithMediaView(val value: AppBskyEmbedRecordWithMediaView) : AppBskyEmbedRecordViewRecordEmbedsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyEmbedRecordViewRecordEmbedsUnion
}

    @Serializable
    data class AppBskyEmbedRecordView(
        @SerialName("record")
        val record: AppBskyEmbedRecordViewRecordUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordView"
        }
    }

    @Serializable
    data class AppBskyEmbedRecordViewRecord(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefsProfileViewBasic,/** The record data itself. */        @SerialName("value")
        val value: JsonElement,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefsLabel>?,        @SerialName("replyCount")
        val replyCount: Int?,        @SerialName("repostCount")
        val repostCount: Int?,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("quoteCount")
        val quoteCount: Int?,        @SerialName("embeds")
        val embeds: List<AppBskyEmbedRecordViewRecordEmbedsUnion>?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordViewRecord"
        }
    }

    @Serializable
    data class AppBskyEmbedRecordViewNotFound(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("notFound")
        val notFound: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordViewNotFound"
        }
    }

    @Serializable
    data class AppBskyEmbedRecordViewBlocked(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("blocked")
        val blocked: Boolean,        @SerialName("author")
        val author: AppBskyFeedDefsBlockedAuthor    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordViewBlocked"
        }
    }

    @Serializable
    data class AppBskyEmbedRecordViewDetached(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("detached")
        val detached: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordViewDetached"
        }
    }

@Serializable
data class AppBskyEmbedRecord(
    @SerialName("record")
    val record: ComAtprotoRepoStrongRef)
