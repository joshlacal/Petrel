// Lexicon: 1, ID: app.bsky.embed.images
// A set of images embedded in a Bluesky record (eg, a post).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyEmbedImages {
    const val TYPE_IDENTIFIER = "app.bsky.embed.images"

        @Serializable
    data class Image(
        @SerialName("image")
        val image: Blob,/** Alt text description of the image, for accessibility. */        @SerialName("alt")
        val alt: String,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefs.Aspectratio?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#image"
        }
    }

    @Serializable
    data class View(
        @SerialName("images")
        val images: List<Viewimage>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#view"
        }
    }

    @Serializable
    data class Viewimage(
/** Fully-qualified URL where a thumbnail of the image can be fetched. For example, CDN location provided by the App View. */        @SerialName("thumb")
        val thumb: URI,/** Fully-qualified URL where a large version of the image can be fetched. May or may not be the exact original blob. For example, CDN location provided by the App View. */        @SerialName("fullsize")
        val fullsize: URI,/** Alt text description of the image, for accessibility. */        @SerialName("alt")
        val alt: String,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefs.Aspectratio?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#viewimage"
        }
    }

    @Serializable
data class AppBskyEmbedImages(
    @SerialName("images")
    val images: List<Image>)
}
