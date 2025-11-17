// Lexicon: 1, ID: app.bsky.graph.follow
// Record declaring a social 'follow' relationship of another account. Duplicate follows will be ignored by the AppView.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphFollow {
    const val TYPE_IDENTIFIER = "app.bsky.graph.follow"

        /**
     * Record declaring a social 'follow' relationship of another account. Duplicate follows will be ignored by the AppView.
     */
    @Serializable
    data class Record(
        @SerialName("subject")
        val subject: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
