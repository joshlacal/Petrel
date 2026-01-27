// Lexicon: 1, ID: app.bsky.embed.video
// A video embedded in a Bluesky record (eg, a post).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyEmbedVideoDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.video"
}

    @Serializable
    data class AppBskyEmbedVideoCaption(
        @SerialName("lang")
        val lang: Language,        @SerialName("file")
        val `file`: Blob    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedVideoCaption"
        }
    }

    @Serializable
    data class AppBskyEmbedVideoView(
        @SerialName("cid")
        val cid: CID,        @SerialName("playlist")
        val playlist: URI,        @SerialName("thumbnail")
        val thumbnail: URI?,        @SerialName("alt")
        val alt: String?,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefsAspectRatio?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedVideoView"
        }
    }

@Serializable
data class AppBskyEmbedVideo(
// The mp4 video file. May be up to 100mb, formerly limited to 50mb.    @SerialName("video")
    val video: Blob,    @SerialName("captions")
    val captions: List<AppBskyEmbedVideoCaption>?,// Alt text description of the video, for accessibility.    @SerialName("alt")
    val alt: String?,    @SerialName("aspectRatio")
    val aspectRatio: AppBskyEmbedDefsAspectRatio?)
