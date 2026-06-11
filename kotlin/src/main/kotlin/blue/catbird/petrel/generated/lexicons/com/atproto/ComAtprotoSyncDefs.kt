// Lexicon: 1, ID: com.atproto.sync.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
