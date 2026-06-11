// Lexicon: 1, ID: app.bsky.embed.images
// A set of images embedded in a Bluesky record (eg, a post).
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyEmbedImagesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.images"
}

    @Serializable
    data class AppBskyEmbedImagesImage(
/** The raw image file. May be up to 2 MB, formerly limited to 1 MB. */        @SerialName("image")
        val image: Blob,/** Alt text description of the image, for accessibility. */        @SerialName("alt")
        val alt: String,        @SerialName("aspectRatio")
        val aspectRatio: AppBskyEmbedDefsAspectRatio? = null    ) {
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
        val aspectRatio: AppBskyEmbedDefsAspectRatio? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedImagesViewImage"
        }
    }

@Serializable
data class AppBskyEmbedImages(
    @SerialName("images")
    val images: List<AppBskyEmbedImagesImage>)
