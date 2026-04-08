// Lexicon: 1, ID: place.stream.chat.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamChatDefsDefs {
    const val TYPE_IDENTIFIER = "place.stream.chat.defs"
}

@Serializable
sealed interface PlaceStreamChatDefsMessageViewReplyToUnion {
    @Serializable
    @SerialName("place.stream.chat.defs#PlaceStreamChatDefsMessageView")
    data class PlaceStreamChatDefsMessageView(val value: PlaceStreamChatDefsMessageView) : PlaceStreamChatDefsMessageViewReplyToUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : PlaceStreamChatDefsMessageViewReplyToUnion
}

    @Serializable
    data class PlaceStreamChatDefsMessageView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("author")
        val author: AppBskyActorDefsProfileViewBasic,        @SerialName("record")
        val record: JsonElement,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("chatProfile")
        val chatProfile: PlaceStreamChatProfile?,        @SerialName("replyTo")
        val replyTo: PlaceStreamChatDefsMessageViewReplyToUnion?,/** If true, this message has been deleted or labeled and should be cleared from the cache */        @SerialName("deleted")
        val deleted: Boolean?,/** Up to 3 badge tokens to display with the message. First badge is server-controlled, remaining badges are user-settable. Tokens are looked up in badges.json for display info. */        @SerialName("badges")
        val badges: List<PlaceStreamBadgeDefsBadgeView>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamChatDefsMessageView"
        }
    }

    /**
     * View of a pinned chat record with hydrated message data.
     */
    @Serializable
    data class PlaceStreamChatDefsPinnedRecordView(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("record")
        val record: PlaceStreamChatPinnedRecord,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("pinnedBy")
        val pinnedBy: PlaceStreamChatProfile?,        @SerialName("message")
        val message: PlaceStreamChatDefsMessageView?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamChatDefsPinnedRecordView"
        }
    }
