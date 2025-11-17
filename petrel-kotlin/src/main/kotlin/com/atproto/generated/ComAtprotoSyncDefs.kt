// Lexicon: 1, ID: com.atproto.sync.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

@Serializable
enum class Hoststatus {
    @SerialName("active")
    ACTIVE,    @SerialName("idle")
    IDLE,    @SerialName("offline")
    OFFLINE,    @SerialName("throttled")
    THROTTLED,    @SerialName("banned")
    BANNED}

object ComAtprotoSyncDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.defs"

}
