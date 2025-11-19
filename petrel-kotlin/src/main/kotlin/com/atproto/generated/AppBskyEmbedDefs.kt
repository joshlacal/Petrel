// Lexicon: 1, ID: app.bsky.embed.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyEmbedDefs {
    const val TYPE_IDENTIFIER = "app.bsky.embed.defs"

        /**
     * width:height represents an aspect ratio. It may be approximate, and may not correspond to absolute dimensions in any given unit.
     */
    @Serializable
    data class Aspectratio(
        @SerialName("width")
        val width: Int,        @SerialName("height")
        val height: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#aspectratio"
        }
    }

}
