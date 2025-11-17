// Lexicon: 1, ID: app.bsky.graph.block
// Record declaring a 'block' relationship against another account. NOTE: blocks are public in Bluesky; see blog posts for details.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphBlock {
    const val TYPE_IDENTIFIER = "app.bsky.graph.block"

        /**
     * Record declaring a 'block' relationship against another account. NOTE: blocks are public in Bluesky; see blog posts for details.
     */
    @Serializable
    data class Record(
/** DID of the account to be blocked. */        @SerialName("subject")
        val subject: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
