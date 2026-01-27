// Lexicon: 1, ID: app.bsky.embed.external
// A representation of some externally linked content (eg, a URL and 'card'), embedded in a Bluesky record (eg, a post).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyEmbedExternalDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.external"
}

    @Serializable
    data class AppBskyEmbedExternalExternal(
        @SerialName("uri")
        val uri: URI,        @SerialName("title")
        val title: String,        @SerialName("description")
        val description: String,        @SerialName("thumb")
        val thumb: Blob?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedExternalExternal"
        }
    }

    @Serializable
    data class AppBskyEmbedExternalView(
        @SerialName("external")
        val external: AppBskyEmbedExternalViewExternal    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedExternalView"
        }
    }

    @Serializable
    data class AppBskyEmbedExternalViewExternal(
        @SerialName("uri")
        val uri: URI,        @SerialName("title")
        val title: String,        @SerialName("description")
        val description: String,        @SerialName("thumb")
        val thumb: URI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedExternalViewExternal"
        }
    }

@Serializable
data class AppBskyEmbedExternal(
    @SerialName("external")
    val external: AppBskyEmbedExternalExternal)
