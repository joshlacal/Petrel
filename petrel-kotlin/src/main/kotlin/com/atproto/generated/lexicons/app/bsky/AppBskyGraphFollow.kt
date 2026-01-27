// Lexicon: 1, ID: app.bsky.graph.follow
// Record declaring a social 'follow' relationship of another account. Duplicate follows will be ignored by the AppView.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphFollowDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.follow"
}

    /**
     * Record declaring a social 'follow' relationship of another account. Duplicate follows will be ignored by the AppView.
     */
    @Serializable
    data class AppBskyGraphFollow(
        @SerialName("subject")
        val subject: DID,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
