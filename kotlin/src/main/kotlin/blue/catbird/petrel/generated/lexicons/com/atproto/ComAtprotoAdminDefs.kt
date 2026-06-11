// Lexicon: 1, ID: com.atproto.admin.defs

package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object ComAtprotoAdminDefsDefs {
    const val TYPE_IDENTIFIER = "com.atproto.admin.defs"
}

    @Serializable
    data class ComAtprotoAdminDefsStatusAttr(
        @SerialName("applied")
        val applied: Boolean,        @SerialName("ref")
        val ref: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#comAtprotoAdminDefsStatusAttr"
        }
    }

    @Serializable
    data class ComAtprotoAdminDefsAccountView(
        @SerialName("did")
        val did: DID,        @SerialName("handle")
        val handle: Handle,        @SerialName("email")
        val email: String? = null,        @SerialName("relatedRecords")
        val relatedRecords: List<JsonElement>? = null,        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("invitedBy")
        val invitedBy: ComAtprotoServerDefsInviteCode? = null,        @SerialName("invites")
        val invites: List<ComAtprotoServerDefsInviteCode>? = null,        @SerialName("invitesDisabled")
        val invitesDisabled: Boolean? = null,        @SerialName("emailConfirmedAt")
        val emailConfirmedAt: ATProtocolDate? = null,        @SerialName("inviteNote")
        val inviteNote: String? = null,        @SerialName("deactivatedAt")
        val deactivatedAt: ATProtocolDate? = null,        @SerialName("threatSignatures")
        val threatSignatures: List<ComAtprotoAdminDefsThreatSignature>? = null    ) {
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
        val recordUri: ATProtocolURI? = null    ) {
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
