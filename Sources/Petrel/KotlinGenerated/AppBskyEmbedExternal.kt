// Lexicon: 1, ID: app.bsky.embed.external
// A representation of some externally linked content (eg, a URL and 'card'), embedded in a Bluesky record (eg, a post).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyEmbedExternal {
    const val TYPE_IDENTIFIER = "app.bsky.embed.external"

        @Serializable
    data class External(
        @SerialName("uri")
        val uri: URI,        @SerialName("title")
        val title: String,        @SerialName("description")
        val description: String,        @SerialName("thumb")
        val thumb: Blob?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#external"
        }
    }

    @Serializable
    data class View(
        @SerialName("external")
        val external: Viewexternal    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#view"
        }
    }

    @Serializable
    data class Viewexternal(
        @SerialName("uri")
        val uri: URI,        @SerialName("title")
        val title: String,        @SerialName("description")
        val description: String,        @SerialName("thumb")
        val thumb: URI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#viewexternal"
        }
    }

    @Serializable
data class AppBskyEmbedExternal(
    @SerialName("external")
    val external: External)
}
