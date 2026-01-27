// Lexicon: 1, ID: blue.catbird.mls.removeMember
// Remove (kick) a member from conversation (admin-only) Remove a member from the conversation. Admin-only operation. Server authorizes, soft-deletes membership (sets left_at), and logs action. The admin client must issue an MLS Remove commit via the standard MLS flow to cryptographically remove the member and advance the epoch.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsRemoveMemberDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.removeMember"
}

@Serializable
    data class BlueCatbirdMlsRemoveMemberInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member to remove        @SerialName("targetDid")
        val targetDid: DID,// Client-generated ULID for idempotent removal operations        @SerialName("idempotencyKey")
        val idempotencyKey: String,// Optional reason for removal (logged in audit trail)        @SerialName("reason")
        val reason: String? = null    )

    @Serializable
    data class BlueCatbirdMlsRemoveMemberOutput(
// Whether removal authorization succeeded        @SerialName("ok")
        val ok: Boolean,// Server's current observed epoch (hint for client MLS operations)        @SerialName("epochHint")
        val epochHint: Int? = null    )

sealed class BlueCatbirdMlsRemoveMemberError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsRemoveMemberError("NotAdmin", "Caller is not an admin")
        object NotMember: BlueCatbirdMlsRemoveMemberError("NotMember", "Target is not a member")
        object CannotRemoveSelf: BlueCatbirdMlsRemoveMemberError("CannotRemoveSelf", "Use leaveConvo to remove yourself")
        object ConvoNotFound: BlueCatbirdMlsRemoveMemberError("ConvoNotFound", "Conversation not found")
    }

/**
 * Remove (kick) a member from conversation (admin-only) Remove a member from the conversation. Admin-only operation. Server authorizes, soft-deletes membership (sets left_at), and logs action. The admin client must issue an MLS Remove commit via the standard MLS flow to cryptographically remove the member and advance the epoch.
 *
 * Endpoint: blue.catbird.mls.removeMember
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.removeMember(
input: BlueCatbirdMlsRemoveMemberInput): ATProtoResponse<BlueCatbirdMlsRemoveMemberOutput> {
    val endpoint = "blue.catbird.mls.removeMember"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
