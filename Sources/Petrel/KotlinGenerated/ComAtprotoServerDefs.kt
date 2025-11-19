// Lexicon: 1, ID: com.atproto.server.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoServerDefs {
    const val TYPE_IDENTIFIER = "com.atproto.server.defs"

        @Serializable
    data class Invitecode(
        @SerialName("code")
        val code: String,        @SerialName("available")
        val available: Int,        @SerialName("disabled")
        val disabled: Boolean,        @SerialName("forAccount")
        val forAccount: String,        @SerialName("createdBy")
        val createdBy: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("uses")
        val uses: List<Invitecodeuse>    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#invitecode"
        }
    }

    @Serializable
    data class Invitecodeuse(
        @SerialName("usedBy")
        val usedBy: DID,        @SerialName("usedAt")
        val usedAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#invitecodeuse"
        }
    }

}
