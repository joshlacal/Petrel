// Lexicon: 1, ID: com.atproto.admin.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object ComAtprotoAdminDefsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.defs"
}

    @Serializable
    data class ComAtprotoAdminDefsStatusAttr(
        @SerialName("applied")
        val applied: Boolean,        @SerialName("ref")
        val ref: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoAdminDefsStatusAttr"
        }
    }

    @Serializable
    data class ComAtprotoAdminDefsAccountView(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("email")
        val email: String?,        @SerialName("relatedRecords")
        val relatedRecords: List<JsonElement>?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("invitedBy")
        val invitedBy: ComAtprotoServerDefsInviteCode?,        @SerialName("invites")
        val invites: List<ComAtprotoServerDefsInviteCode>?,        @SerialName("invitesDisabled")
        val invitesDisabled: Boolean?,        @SerialName("emailConfirmedAt")
        val emailConfirmedAt: ATProtocolDate?,        @SerialName("inviteNote")
        val inviteNote: String?,        @SerialName("deactivatedAt")
        val deactivatedAt: ATProtocolDate?,        @SerialName("threatSignatures")
        val threatSignatures: List<ComAtprotoAdminDefsThreatSignature>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoAdminDefsAccountView"
        }
    }

    @Serializable
    data class ComAtprotoAdminDefsRepoRef(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoAdminDefsRepoRef"
        }
    }

    @Serializable
    data class ComAtprotoAdminDefsRepoBlobRef(
        @SerialName("did")
        val did: DID,        @SerialName("cid")
        val cid: CID,        @SerialName("recordUri")
        val recordUri: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoAdminDefsRepoBlobRef"
        }
    }

    @Serializable
    data class ComAtprotoAdminDefsThreatSignature(
        @SerialName("property")
        val property: String,        @SerialName("value")
        val value: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoAdminDefsThreatSignature"
        }
    }
