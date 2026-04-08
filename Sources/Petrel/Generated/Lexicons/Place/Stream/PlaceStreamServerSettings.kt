// Lexicon: 1, ID: place.stream.server.settings
// Record containing user settings for a particular Streamplace node
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamServerSettingsDefs {
    const val TYPE_IDENTIFIER = "place.stream.server.settings"
}

    /**
     * Record containing user settings for a particular Streamplace node
     */
    @Serializable
    data class PlaceStreamServerSettings(
/** Whether this node may archive your livestream for improving the service */        @SerialName("debugRecording")
        val debugRecording: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = ""
        }
    }
