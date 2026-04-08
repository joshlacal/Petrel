// Lexicon: 1, ID: blue.catbird.mlsChat.removeMember
// Remove (kick) a member from conversation (admin-only) Remove a member from the conversation. Admin-only operation. Server authorizes, soft-deletes membership (sets left_at), and logs action. The admin client must issue an MLS Remove commit via the standard MLS flow to cryptographically remove the member and advance the epoch.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatRemoveMemberDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.removeMember"
}

@Serializable
    data class BlueCatbirdMlsChatRemoveMemberInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member to remove        @SerialName("targetDid")
        val targetDid: DID,// Client-generated ULID for idempotent removal operations        @SerialName("idempotencyKey")
        val idempotencyKey: String,// Optional reason for removal (logged in audit trail)        @SerialName("reason")
        val reason: String? = null,// Base64-encoded MLS commit message. REQUIRED for epoch synchronization. Without this, other members cannot advance epochs and will be unable to decrypt subsequent messages.        @SerialName("commit")
        val commit: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatRemoveMemberOutput(
// Whether removal authorization succeeded        @SerialName("ok")
        val ok: Boolean,// Server's current observed epoch (hint for client MLS operations)        @SerialName("epochHint")
        val epochHint: Int? = null    )

sealed class BlueCatbirdMlsChatRemoveMemberError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsChatRemoveMemberError("NotAdmin", "Caller is not an admin")
        object NotMember: BlueCatbirdMlsChatRemoveMemberError("NotMember", "Target is not a member")
        object CannotRemoveSelf: BlueCatbirdMlsChatRemoveMemberError("CannotRemoveSelf", "Use leaveConvo to remove yourself")
        object ConvoNotFound: BlueCatbirdMlsChatRemoveMemberError("ConvoNotFound", "Conversation not found")
    }

/**
 * Remove (kick) a member from conversation (admin-only) Remove a member from the conversation. Admin-only operation. Server authorizes, soft-deletes membership (sets left_at), and logs action. The admin client must issue an MLS Remove commit via the standard MLS flow to cryptographically remove the member and advance the epoch.
 *
 * Endpoint: blue.catbird.mlsChat.removeMember
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.removeMember(
input: BlueCatbirdMlsChatRemoveMemberInput): ATProtoResponse<BlueCatbirdMlsChatRemoveMemberOutput> {
    val endpoint = "blue.catbird.mlsChat.removeMember"

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
