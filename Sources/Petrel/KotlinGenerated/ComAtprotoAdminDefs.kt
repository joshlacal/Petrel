// Lexicon: 1, ID: com.atproto.admin.defs

package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object ComAtprotoAdminDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.defs"

        @Serializable
    data class Statusattr(
        @SerialName("applied")
        val applied: Boolean,        @SerialName("ref")
        val ref: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#statusattr"
        }
    }

    @Serializable
    data class Accountview(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("email")
        val email: String?,        @SerialName("relatedRecords")
        val relatedRecords: List<JsonElement>?,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("invitedBy")
        val invitedBy: ComAtprotoServerDefs.Invitecode?,        @SerialName("invites")
        val invites: List<ComAtprotoServerDefs.Invitecode>?,        @SerialName("invitesDisabled")
        val invitesDisabled: Boolean?,        @SerialName("emailConfirmedAt")
        val emailConfirmedAt: ATProtocolDate?,        @SerialName("inviteNote")
        val inviteNote: String?,        @SerialName("deactivatedAt")
        val deactivatedAt: ATProtocolDate?,        @SerialName("threatSignatures")
        val threatSignatures: List<Threatsignature>?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#accountview"
        }
    }

    @Serializable
    data class Reporef(
        @SerialName("did")
        val did: DID    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#reporef"
        }
    }

    @Serializable
    data class Repoblobref(
        @SerialName("did")
        val did: DID,        @SerialName("cid")
        val cid: CID,        @SerialName("recordUri")
        val recordUri: ATProtocolURI?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#repoblobref"
        }
    }

    @Serializable
    data class Threatsignature(
        @SerialName("property")
        val property: String,        @SerialName("value")
        val value: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#threatsignature"
        }
    }

}
