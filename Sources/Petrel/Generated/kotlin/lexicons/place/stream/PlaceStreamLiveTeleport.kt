// Lexicon: 1, ID: place.stream.live.teleport
// Record defining a 'teleport', that is active during a certain time.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveTeleportDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.teleport"
}

    /**
     * Record defining a 'teleport', that is active during a certain time.
     */
    @Serializable
    data class PlaceStreamLiveTeleport(
/** The DID of the streamer to teleport to. */        @SerialName("streamer")
        val streamer: DID,/** The time the teleport becomes active. */        @SerialName("startsAt")
        val startsAt: ATProtocolDate,/** The time limit in seconds for the teleport. If not set, the teleport is permanent. Must be at least 60 seconds, and no more than 32,400 seconds (9 hours). */        @SerialName("durationSeconds")
        val durationSeconds: Int? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
