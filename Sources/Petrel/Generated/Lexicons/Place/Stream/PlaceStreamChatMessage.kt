// Lexicon: 1, ID: place.stream.chat.message
// Record containing a Streamplace chat message.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamChatMessageDefs {
    const val TYPE_IDENTIFIER = "place.stream.chat.message"
}

    @Serializable
    data class PlaceStreamChatMessageReplyRef(
        @SerialName("root")
        val root: ComAtprotoRepoStrongRef,        @SerialName("parent")
        val parent: ComAtprotoRepoStrongRef    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamChatMessageReplyRef"
        }
    }

    /**
     * Record containing a Streamplace chat message.
     */
    @Serializable
    data class PlaceStreamChatMessage(
/** The primary message content. May be an empty string, if there are embeds. */        @SerialName("text")
        val text: String,/** Client-declared timestamp when this message was originally created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** Annotations of text (mentions, URLs, etc) */        @SerialName("facets")
        val facets: List<PlaceStreamRichtextFacet>? = null,/** The DID of the streamer whose chat this is. */        @SerialName("streamer")
        val streamer: DID,        @SerialName("reply")
        val reply: PlaceStreamChatMessageReplyRef? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
