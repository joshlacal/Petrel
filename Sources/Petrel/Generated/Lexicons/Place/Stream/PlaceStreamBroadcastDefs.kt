// Lexicon: 1, ID: place.stream.broadcast.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamBroadcastDefsDefs {
    const val TYPE_IDENTIFIER = "place.stream.broadcast.defs"
}

    @Serializable
    data class PlaceStreamBroadcastDefsBroadcastOriginView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefsProfileViewBasic,        @SerialName("record")
        val record: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamBroadcastDefsBroadcastOriginView"
        }
    }
