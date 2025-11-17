// Lexicon: 1, ID: chat.bsky.actor.declaration
// A declaration of a Bluesky chat account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ChatBskyActorDeclaration {
    const val TYPE_IDENTIFIER = "chat.bsky.actor.declaration"

        /**
     * A declaration of a Bluesky chat account.
     */
    @Serializable
    data class Record(
        @SerialName("allowIncoming")
        val allowIncoming: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
