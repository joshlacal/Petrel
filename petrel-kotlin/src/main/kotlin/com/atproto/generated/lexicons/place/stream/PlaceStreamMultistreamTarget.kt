// Lexicon: 1, ID: place.stream.multistream.target
// An external server for rebroadcasting a Streamplace stream
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMultistreamTargetDefs {
    const val TYPE_IDENTIFIER = "place.stream.multistream.target"
}

    /**
     * An external server for rebroadcasting a Streamplace stream
     */
    @Serializable
    data class PlaceStreamMultistreamTarget(
/** The rtmp:// or rtmps:// url of the target server. */        @SerialName("url")
        val url: URI,/** Whether this target is currently active. */        @SerialName("active")
        val active: Boolean,/** When this target was created. */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** A user-friendly name for this target. */        @SerialName("name")
        val name: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
