// Lexicon: 1, ID: place.stream.chat.gate
// Record defining a single gated chat message.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamChatGateDefs {
    const val TYPE_IDENTIFIER = "place.stream.chat.gate"
}

    /**
     * Record defining a single gated chat message.
     */
    @Serializable
    data class PlaceStreamChatGate(
/** URI of the hidden chat message. */        @SerialName("hiddenMessage")
        val hiddenMessage: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
