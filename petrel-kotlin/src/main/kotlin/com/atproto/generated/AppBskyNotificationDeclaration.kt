// Lexicon: 1, ID: app.bsky.notification.declaration
// A declaration of the user's choices related to notifications that can be produced by them.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyNotificationDeclaration {
    const val TYPE_IDENTIFIER = "app.bsky.notification.declaration"

        /**
     * A declaration of the user's choices related to notifications that can be produced by them.
     */
    @Serializable
    data class Record(
/** A declaration of the user's preference for allowing activity subscriptions from other users. Absence of a record implies 'followers'. */        @SerialName("allowSubscriptions")
        val allowSubscriptions: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }

}
