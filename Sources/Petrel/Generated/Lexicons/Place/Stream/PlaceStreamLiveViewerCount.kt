// Lexicon: 1, ID: place.stream.live.viewerCount
// Current viewer count for a livestream on a particular server. Record keys are streamer_did::server_did by convention.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveViewerCountDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.viewerCount"
}

    /**
     * Current viewer count for a livestream on a particular server. Record keys are streamer_did::server_did by convention.
     */
    @Serializable
    data class PlaceStreamLiveViewerCount(
/** The DID of the streamer to teleport to. */        @SerialName("streamer")
        val streamer: DID,/** The DID of the server to get the view count for. */        @SerialName("server")
        val server: DID,/** The current view count for the livestream. */        @SerialName("count")
        val count: Int,/** The time the view count was last updated. */        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
