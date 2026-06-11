// Lexicon: 1, ID: app.bsky.embed.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyEmbedDefsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.defs"
}

    /**
     * width:height represents an aspect ratio. It may be approximate, and may not correspond to absolute dimensions in any given unit.
     */
    @Serializable
    data class AppBskyEmbedDefsAspectRatio(
        @SerialName("width")
        val width: Int,        @SerialName("height")
        val height: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyEmbedDefsAspectRatio"
        }
    }
