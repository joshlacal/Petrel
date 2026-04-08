// Lexicon: 1, ID: place.stream.live.recommendations
// A list of recommended streamers, in order of preference
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveRecommendationsDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.recommendations"
}

    /**
     * A list of recommended streamers, in order of preference
     */
    @Serializable
    data class PlaceStreamLiveRecommendations(
/** Ordered list of recommended streamer DIDs */        @SerialName("streamers")
        val streamers: List<DID>,/** Client-declared timestamp when this list was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
