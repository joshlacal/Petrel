// Lexicon: 1, ID: blue.catbird.mls.promoteModerator
// Promote a member to moderator status (admin-only operation) Promote a conversation member to moderator. Caller must be an existing admin. Moderators can warn members and view reports but cannot promote/demote others.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsPromoteModeratorDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.promoteModerator"
}

@Serializable
    data class BlueCatbirdMlsPromoteModeratorInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member to promote to moderator        @SerialName("targetDid")
        val targetDid: DID    )

    @Serializable
    data class BlueCatbirdMlsPromoteModeratorOutput(
// Whether promotion succeeded        @SerialName("ok")
        val ok: Boolean,// Timestamp when member was promoted to moderator        @SerialName("promotedAt")
        val promotedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsPromoteModeratorError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsPromoteModeratorError("NotAdmin", "Caller is not an admin of this conversation")
        object NotMember: BlueCatbirdMlsPromoteModeratorError("NotMember", "Target is not a member of this conversation")
        object AlreadyModerator: BlueCatbirdMlsPromoteModeratorError("AlreadyModerator", "Target is already a moderator")
        object IsAdmin: BlueCatbirdMlsPromoteModeratorError("IsAdmin", "Target is an admin (admins have moderator privileges)")
        object ConvoNotFound: BlueCatbirdMlsPromoteModeratorError("ConvoNotFound", "Conversation not found")
    }

/**
 * Promote a member to moderator status (admin-only operation) Promote a conversation member to moderator. Caller must be an existing admin. Moderators can warn members and view reports but cannot promote/demote others.
 *
 * Endpoint: blue.catbird.mls.promoteModerator
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.promoteModerator(
input: BlueCatbirdMlsPromoteModeratorInput): ATProtoResponse<BlueCatbirdMlsPromoteModeratorOutput> {
    val endpoint = "blue.catbird.mls.promoteModerator"

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
