// Lexicon: 1, ID: app.bsky.graph.starterpack
// Record defining a starter pack of actors and feeds for new users.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphStarterpackDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.starterpack"
}

    @Serializable
    data class AppBskyGraphStarterpackFeedItem(
        @SerialName("uri")
        val uri: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyGraphStarterpackFeedItem"
        }
    }

    /**
     * Record defining a starter pack of actors and feeds for new users.
     */
    @Serializable
    data class AppBskyGraphStarterpack(
/** Display name for starter pack; can not be empty. */        @SerialName("name")
        val name: String,        @SerialName("description")
        val description: String? = null,        @SerialName("descriptionFacets")
        val descriptionFacets: List<AppBskyRichtextFacet>? = null,/** Reference (AT-URI) to the list record. */        @SerialName("list")
        val list: ATProtocolURI,        @SerialName("feeds")
        val feeds: List<AppBskyGraphStarterpackFeedItem>? = null,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
