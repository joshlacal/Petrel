// Lexicon: 1, ID: app.bsky.embed.images
// A set of images embedded in a Bluesky record (eg, a post).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyEmbedImagesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.images"
}

    @Serializable
    data class AppBskyEmbedImagesImage(
        @SerialName("image")
        val image: Blob,/** Alt text description of the image, for accessibility. */        @SerialName("alt")
        val alt: String,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefsAspectRatio?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedImagesImage"
        }
    }

    @Serializable
    data class AppBskyEmbedImagesView(
        @SerialName("images")
        val images: List<AppBskyEmbedImagesViewImage>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedImagesView"
        }
    }

    @Serializable
    data class AppBskyEmbedImagesViewImage(
/** Fully-qualified URL where a thumbnail of the image can be fetched. For example, CDN location provided by the App View. */        @SerialName("thumb")
        val thumb: URI,/** Fully-qualified URL where a large version of the image can be fetched. May or may not be the exact original blob. For example, CDN location provided by the App View. */        @SerialName("fullsize")
        val fullsize: URI,/** Alt text description of the image, for accessibility. */        @SerialName("alt")
        val alt: String,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefsAspectRatio?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedImagesViewImage"
        }
    }

@Serializable
data class AppBskyEmbedImages(
    @SerialName("images")
    val images: List<AppBskyEmbedImagesImage>)
