// Lexicon: 1, ID: app.bsky.graph.listblock
// Record representing a block relationship against an entire an entire list of accounts (actors).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphListblockDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.listblock"
}

    /**
     * Record representing a block relationship against an entire an entire list of accounts (actors).
     */
    @Serializable
    data class AppBskyGraphListblock(
/** Reference (AT-URI) to the mod list record. */        @SerialName("subject")
        val subject: ATProtocolURI,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
