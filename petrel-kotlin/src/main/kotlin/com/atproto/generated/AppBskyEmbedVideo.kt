// Lexicon: 1, ID: app.bsky.embed.video
// A video embedded in a Bluesky record (eg, a post).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyEmbedVideo {
    const val TYPE_IDENTIFIER = "app.bsky.embed.video"

        @Serializable
    data class Caption(
        @SerialName("lang")
        val lang: Language,        @SerialName("file")
        val `file`: Blob    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#caption"
        }
    }

    @Serializable
    data class View(
        @SerialName("cid")
        val cid: CID,        @SerialName("playlist")
        val playlist: URI,        @SerialName("thumbnail")
        val thumbnail: URI?,        @SerialName("alt")
        val alt: String?,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefs.Aspectratio?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#view"
        }
    }

    @Serializable
data class AppBskyEmbedVideo(
// The mp4 video file. May be up to 100mb, formerly limited to 50mb.    @SerialName("video")
    val video: Blob,    @SerialName("captions")
    val captions: List<Caption>?,// Alt text description of the video, for accessibility.    @SerialName("alt")
    val alt: String?,    @SerialName("aspectRatio")
    val aspectRatio: AppBskyEmbedDefs.Aspectratio?)
}
