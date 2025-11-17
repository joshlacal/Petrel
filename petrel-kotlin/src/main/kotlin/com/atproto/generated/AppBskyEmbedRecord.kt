// Lexicon: 1, ID: app.bsky.embed.record
// A representation of a record embedded in a Bluesky record (eg, a post). For example, a quote-post, or sharing a feed generator record.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface ViewRecordUnion {
    @Serializable
    @SerialName("app.bsky.embed.record#Viewrecord")
    data class Viewrecord(val value: Viewrecord) : ViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#Viewnotfound")
    data class Viewnotfound(val value: Viewnotfound) : ViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#Viewblocked")
    data class Viewblocked(val value: Viewblocked) : ViewRecordUnion

    @Serializable
    @SerialName("app.bsky.embed.record#Viewdetached")
    data class Viewdetached(val value: Viewdetached) : ViewRecordUnion

    @Serializable
    @SerialName("AppBskyFeedDefs.Generatorview")
    data class Generatorview(val value: AppBskyFeedDefs.Generatorview) : ViewRecordUnion

    @Serializable
    @SerialName("AppBskyGraphDefs.Listview")
    data class Listview(val value: AppBskyGraphDefs.Listview) : ViewRecordUnion

    @Serializable
    @SerialName("AppBskyLabelerDefs.Labelerview")
    data class Labelerview(val value: AppBskyLabelerDefs.Labelerview) : ViewRecordUnion

    @Serializable
    @SerialName("AppBskyGraphDefs.Starterpackviewbasic")
    data class Starterpackviewbasic(val value: AppBskyGraphDefs.Starterpackviewbasic) : ViewRecordUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ViewRecordUnion
}

@Serializable
sealed interface ViewrecordEmbedsUnion {
    @Serializable
    @SerialName("AppBskyEmbedImages.View")
    data class View(val value: AppBskyEmbedImages.View) : ViewrecordEmbedsUnion

    @Serializable
    @SerialName("AppBskyEmbedVideo.View")
    data class View(val value: AppBskyEmbedVideo.View) : ViewrecordEmbedsUnion

    @Serializable
    @SerialName("AppBskyEmbedExternal.View")
    data class View(val value: AppBskyEmbedExternal.View) : ViewrecordEmbedsUnion

    @Serializable
    @SerialName("AppBskyEmbedRecord.View")
    data class View(val value: AppBskyEmbedRecord.View) : ViewrecordEmbedsUnion

    @Serializable
    @SerialName("AppBskyEmbedRecordwithmedia.View")
    data class View(val value: AppBskyEmbedRecordwithmedia.View) : ViewrecordEmbedsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ViewrecordEmbedsUnion
}

object AppBskyEmbedRecord {
    const val TYPE_IDENTIFIER = "app.bsky.embed.record"

        @Serializable
    data class View(
        @SerialName("record")
        val record: ViewRecordUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#view"
        }
    }

    @Serializable
    data class Viewrecord(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefs.Profileviewbasic,/** The record data itself. */        @SerialName("value")
        val value: JsonElement,        @SerialName("labels")
        val labels: List<ComAtprotoLabelDefs.Label>?,        @SerialName("replyCount")
        val replyCount: Int?,        @SerialName("repostCount")
        val repostCount: Int?,        @SerialName("likeCount")
        val likeCount: Int?,        @SerialName("quoteCount")
        val quoteCount: Int?,        @SerialName("embeds")
        val embeds: List<ViewrecordEmbedsUnion>?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#viewrecord"
        }
    }

    @Serializable
    data class Viewnotfound(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("notFound")
        val notFound: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#viewnotfound"
        }
    }

    @Serializable
    data class Viewblocked(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("blocked")
        val blocked: Boolean,        @SerialName("author")
        val author: AppBskyFeedDefs.Blockedauthor    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#viewblocked"
        }
    }

    @Serializable
    data class Viewdetached(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("detached")
        val detached: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#viewdetached"
        }
    }

    @Serializable
data class AppBskyEmbedRecord(
    @SerialName("record")
    val record: ComAtprotoRepoStrongref)
}
