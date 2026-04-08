// Lexicon: 1, ID: app.bsky.notification.declaration
// A declaration of the user's choices related to notifications that can be produced by them.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyNotificationDeclarationDefs {
    const val TYPE_IDENTIFIER = "app.bsky.notification.declaration"
}

    /**
     * A declaration of the user's choices related to notifications that can be produced by them.
     */
    @Serializable
    data class AppBskyNotificationDeclaration(
/** A declaration of the user's preference for allowing activity subscriptions from other users. Absence of a record implies 'followers'. */        @SerialName("allowSubscriptions")
        val allowSubscriptions: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
