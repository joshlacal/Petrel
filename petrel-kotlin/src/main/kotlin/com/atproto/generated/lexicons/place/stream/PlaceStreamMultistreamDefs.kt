// Lexicon: 1, ID: place.stream.multistream.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMultistreamDefsDefs {
    const val TYPE_IDENTIFIER = "place.stream.multistream.defs"
}

    @Serializable
    data class PlaceStreamMultistreamDefsTargetView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("record")
        val record: JsonElement,        @SerialName("latestEvent")
        val latestEvent: PlaceStreamMultistreamDefsEvent?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamMultistreamDefsTargetView"
        }
    }

    @Serializable
    data class PlaceStreamMultistreamDefsEvent(
        @SerialName("message")
        val message: String,        @SerialName("status")
        val status: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamMultistreamDefsEvent"
        }
    }
