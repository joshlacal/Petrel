// Lexicon: 1, ID: place.stream.moderation.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamModerationDefsDefs {
    const val TYPE_IDENTIFIER = "place.stream.moderation.defs"
}

    @Serializable
    data class PlaceStreamModerationDefsPermissionView(
/** AT-URI of the permission record */        @SerialName("uri")
        val uri: ATProtocolURI,/** Content identifier of the permission record */        @SerialName("cid")
        val cid: CID,/** The streamer who granted these permissions */        @SerialName("author")
        val author: AppBskyActorDefsProfileViewBasic,/** The permission record itself */        @SerialName("record")
        val record: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamModerationDefsPermissionView"
        }
    }
