// Lexicon: 1, ID: app.bsky.embed.recordWithMedia
// A representation of a record embedded in a Bluesky record (eg, a post), alongside other compatible embeds. For example, a quote post and image, or a quote post and external URL card.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
sealed interface ViewMediaUnion {
    @Serializable
    @SerialName("AppBskyEmbedImages.View")
    data class View(val value: AppBskyEmbedImages.View) : ViewMediaUnion

    @Serializable
    @SerialName("AppBskyEmbedVideo.View")
    data class View(val value: AppBskyEmbedVideo.View) : ViewMediaUnion

    @Serializable
    @SerialName("AppBskyEmbedExternal.View")
    data class View(val value: AppBskyEmbedExternal.View) : ViewMediaUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : ViewMediaUnion
}

@Serializable
sealed interface AppBskyEmbedRecordwithmediaMediaUnion {
    @Serializable
    @SerialName("app.bsky.embed.recordWithMedia#AppBskyEmbedImages")
    data class AppBskyEmbedImages(val value: AppBskyEmbedImages) : AppBskyEmbedRecordwithmediaMediaUnion

    @Serializable
    @SerialName("app.bsky.embed.recordWithMedia#AppBskyEmbedVideo")
    data class AppBskyEmbedVideo(val value: AppBskyEmbedVideo) : AppBskyEmbedRecordwithmediaMediaUnion

    @Serializable
    @SerialName("app.bsky.embed.recordWithMedia#AppBskyEmbedExternal")
    data class AppBskyEmbedExternal(val value: AppBskyEmbedExternal) : AppBskyEmbedRecordwithmediaMediaUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : AppBskyEmbedRecordwithmediaMediaUnion
}

object AppBskyEmbedRecordwithmedia {
    const val TYPE_IDENTIFIER = "app.bsky.embed.recordWithMedia"

        @Serializable
    data class View(
        @SerialName("record")
        val record: AppBskyEmbedRecord.View,        @SerialName("media")
        val media: ViewMediaUnion    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#view"
        }
    }

    @Serializable
data class AppBskyEmbedRecordwithmedia(
    @SerialName("record")
    val record: AppBskyEmbedRecord,    @SerialName("media")
    val media: AppBskyEmbedRecordwithmediaMediaUnion)
}
