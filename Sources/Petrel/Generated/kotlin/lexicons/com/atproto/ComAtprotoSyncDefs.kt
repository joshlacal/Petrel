// Lexicon: 1, ID: com.atproto.sync.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoSyncDefsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.sync.defs"
}

@Serializable
enum class ComAtprotoSyncDefsHostStatus {
    @SerialName("active")
    ACTIVE,
    @SerialName("idle")
    IDLE,
    @SerialName("offline")
    OFFLINE,
    @SerialName("throttled")
    THROTTLED,
    @SerialName("banned")
    BANNED}
