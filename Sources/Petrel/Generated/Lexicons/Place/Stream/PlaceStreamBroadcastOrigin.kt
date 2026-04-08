// Lexicon: 1, ID: place.stream.broadcast.origin
// Record indicating a livestream is published and available for replication at a given address. By convention, the record key is streamer::server
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamBroadcastOriginDefs {
    const val TYPE_IDENTIFIER = "place.stream.broadcast.origin"
}

    /**
     * Record indicating a livestream is published and available for replication at a given address. By convention, the record key is streamer::server
     */
    @Serializable
    data class PlaceStreamBroadcastOrigin(
/** DID of the streamer whose livestream is being published */        @SerialName("streamer")
        val streamer: DID,/** did of the server that's currently rebroadcasting the livestream */        @SerialName("server")
        val server: DID,/** did of the broadcaster that operates the server syndicating the livestream */        @SerialName("broadcaster")
        val broadcaster: DID? = null,/** Periodically updated timestamp when this origin last saw a livestream */        @SerialName("updatedAt")
        val updatedAt: ATProtocolDate,/** Iroh ticket that can be used to access the livestream from the server */        @SerialName("irohTicket")
        val irohTicket: String? = null,/** URL of the websocket endpoint for the livestream */        @SerialName("websocketURL")
        val websocketURL: URI? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
