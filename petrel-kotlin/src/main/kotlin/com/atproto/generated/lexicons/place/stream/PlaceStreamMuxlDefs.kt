// Lexicon: 1, ID: place.stream.muxl.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMuxlDefsDefs {
    const val TYPE_IDENTIFIER = "place.stream.muxl.defs"
}

    /**
     * A track within a multiplexed stream
     */
    @Serializable
    data class PlaceStreamMuxlDefsTrack(
/** Track identifier */        @SerialName("id")
        val id: Int,/** Codec used for this track */        @SerialName("codec")
        val codec: String,/** Width in pixels (video tracks) */        @SerialName("width")
        val width: Int?,/** Height in pixels (video tracks) */        @SerialName("height")
        val height: Int?,/** Sample rate (audio tracks) */        @SerialName("rate")
        val rate: Int?,/** Number of audio channels */        @SerialName("channels")
        val channels: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamMuxlDefsTrack"
        }
    }
