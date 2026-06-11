// Lexicon: 1, ID: app.bsky.embed.video
// A video embedded in a Bluesky record (eg, a post).
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
        val thumbnail: URI? = null,        @SerialName("alt")
        val alt: String? = null,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefsAspectRatio? = null,/** A hint to the client about how to present the video. */        @SerialName("presentation")
        val presentation: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedVideoView"
        }
    }

@Serializable
data class AppBskyEmbedVideo(
// The mp4 video file. May be up to 100mb, formerly limited to 50mb.    @SerialName("video")
    val video: Blob,    @SerialName("captions")
    val captions: List<AppBskyEmbedVideoCaption>? = null,// Alt text description of the video, for accessibility.    @SerialName("alt")
    val alt: String? = null,    @SerialName("aspectRatio")
    val aspectRatio: AppBskyEmbedDefsAspectRatio? = null,// A hint to the client about how to present the video.    @SerialName("presentation")
    val presentation: String? = null)
