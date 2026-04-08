// Lexicon: 1, ID: place.stream.ingest.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamIngestDefsDefs {
    const val TYPE_IDENTIFIER = "place.stream.ingest.defs"
}

    /**
     * An ingest URL for a Streamplace station.
     */
    @Serializable
    data class PlaceStreamIngestDefsIngest(
/** The type of ingest endpoint, currently 'rtmp' and 'whip' are supported. */        @SerialName("type")
        val type: String,/** The URL of the ingest endpoint. */        @SerialName("url")
        val url: URI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamIngestDefsIngest"
        }
    }
