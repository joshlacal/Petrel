// Lexicon: 1, ID: com.atproto.server.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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
