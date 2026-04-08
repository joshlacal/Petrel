// Lexicon: 1, ID: place.stream.key
// Record linking an atproto identity with a stream signing key
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamKeyDefs {
    const val TYPE_IDENTIFIER = "place.stream.key"
}

    /**
     * Record linking an atproto identity with a stream signing key
     */
    @Serializable
    data class PlaceStreamKey(
/** The did:key signing key for the stream. */        @SerialName("signingKey")
        val signingKey: String,/** Client-declared timestamp when this key was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** The name of the client that created this key. */        @SerialName("createdBy")
        val createdBy: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
