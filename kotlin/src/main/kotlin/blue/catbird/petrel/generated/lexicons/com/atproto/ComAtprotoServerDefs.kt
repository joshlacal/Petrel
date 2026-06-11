// Lexicon: 1, ID: com.atproto.server.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoServerDefsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.defs"
}

    @Serializable
    data class ComAtprotoServerDefsInviteCode(
        @SerialName("code")
        val code: String,        @SerialName("available")
        val available: Int,        @SerialName("disabled")
        val disabled: Boolean,        @SerialName("forAccount")
        val forAccount: String,        @SerialName("createdBy")
        val createdBy: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("uses")
        val uses: List<ComAtprotoServerDefsInviteCodeUse>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoServerDefsInviteCode"
        }
    }

    @Serializable
    data class ComAtprotoServerDefsInviteCodeUse(
        @SerialName("usedBy")
        val usedBy: DID,        @SerialName("usedAt")
        val usedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoServerDefsInviteCodeUse"
        }
    }
