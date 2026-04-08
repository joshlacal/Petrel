// Lexicon: 1, ID: blue.catbird.mlsChat.promoteModerator
// Promote a member to moderator status (admin-only operation) Promote a conversation member to moderator. Caller must be an existing admin. Moderators can warn members and view reports but cannot promote/demote others.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatPromoteModeratorDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.promoteModerator"
}

@Serializable
    data class BlueCatbirdMlsChatPromoteModeratorInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// DID of member to promote to moderator        @SerialName("targetDid")
        val targetDid: DID    )

    @Serializable
    data class BlueCatbirdMlsChatPromoteModeratorOutput(
// Whether promotion succeeded        @SerialName("ok")
        val ok: Boolean,// Timestamp when member was promoted to moderator        @SerialName("promotedAt")
        val promotedAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatPromoteModeratorError(val name: String, val description: String?) {
        object NotAdmin: BlueCatbirdMlsChatPromoteModeratorError("NotAdmin", "Caller is not an admin of this conversation")
        object NotMember: BlueCatbirdMlsChatPromoteModeratorError("NotMember", "Target is not a member of this conversation")
        object AlreadyModerator: BlueCatbirdMlsChatPromoteModeratorError("AlreadyModerator", "Target is already a moderator")
        object IsAdmin: BlueCatbirdMlsChatPromoteModeratorError("IsAdmin", "Target is an admin (admins have moderator privileges)")
        object ConvoNotFound: BlueCatbirdMlsChatPromoteModeratorError("ConvoNotFound", "Conversation not found")
    }

/**
 * Promote a member to moderator status (admin-only operation) Promote a conversation member to moderator. Caller must be an existing admin. Moderators can warn members and view reports but cannot promote/demote others.
 *
 * Endpoint: blue.catbird.mlsChat.promoteModerator
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.promoteModerator(
input: BlueCatbirdMlsChatPromoteModeratorInput): ATProtoResponse<BlueCatbirdMlsChatPromoteModeratorOutput> {
    val endpoint = "blue.catbird.mlsChat.promoteModerator"

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
