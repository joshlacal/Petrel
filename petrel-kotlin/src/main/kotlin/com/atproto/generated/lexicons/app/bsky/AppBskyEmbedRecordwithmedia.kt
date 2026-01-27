// Lexicon: 1, ID: app.bsky.embed.recordWithMedia
// A representation of a record embedded in a Bluesky record (eg, a post), alongside other compatible embeds. For example, a quote post and image, or a quote post and external URL card.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyEmbedRecordWithMediaDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.recordWithMedia"
}

@Serializable
sealed interface AppBskyEmbedRecordWithMediaViewMediaUnion {
    @Serializable
    @SerialName("app.bsky.embed.recordWithMedia#AppBskyEmbedImagesView")
    data class AppBskyEmbedImagesView(val value: AppBskyEmbedImagesView) : AppBskyEmbedRecordWithMediaViewMediaUnion

    @Serializable
    @SerialName("app.bsky.embed.recordWithMedia#AppBskyEmbedVideoView")
    data class AppBskyEmbedVideoView(val value: AppBskyEmbedVideoView) : AppBskyEmbedRecordWithMediaViewMediaUnion

    @Serializable
    @SerialName("app.bsky.embed.recordWithMedia#AppBskyEmbedExternalView")
    data class AppBskyEmbedExternalView(val value: AppBskyEmbedExternalView) : AppBskyEmbedRecordWithMediaViewMediaUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyEmbedRecordWithMediaViewMediaUnion
}

@Serializable
sealed interface AppBskyEmbedRecordWithMediaMediaUnion {
    @Serializable
    @SerialName("app.bsky.embed.recordWithMedia#AppBskyEmbedImages")
    data class AppBskyEmbedImages(val value: AppBskyEmbedImages) : AppBskyEmbedRecordWithMediaMediaUnion

    @Serializable
    @SerialName("app.bsky.embed.recordWithMedia#AppBskyEmbedVideo")
    data class AppBskyEmbedVideo(val value: AppBskyEmbedVideo) : AppBskyEmbedRecordWithMediaMediaUnion

    @Serializable
    @SerialName("app.bsky.embed.recordWithMedia#AppBskyEmbedExternal")
    data class AppBskyEmbedExternal(val value: AppBskyEmbedExternal) : AppBskyEmbedRecordWithMediaMediaUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyEmbedRecordWithMediaMediaUnion
}

    @Serializable
    data class AppBskyEmbedRecordWithMediaView(
        @SerialName("record")
        val record: AppBskyEmbedRecordView,        @SerialName("media")
        val media: AppBskyEmbedRecordWithMediaViewMediaUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedRecordWithMediaView"
        }
    }

@Serializable
data class AppBskyEmbedRecordWithMedia(
    @SerialName("record")
    val record: AppBskyEmbedRecord,    @SerialName("media")
    val media: AppBskyEmbedRecordWithMediaMediaUnion)
