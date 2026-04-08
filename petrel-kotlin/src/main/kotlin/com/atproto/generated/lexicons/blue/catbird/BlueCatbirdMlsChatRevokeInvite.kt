// Lexicon: 1, ID: blue.catbird.mlsChat.revokeInvite
// Revoke an existing invite link Revoke an invite link to prevent further use. Only admins can revoke invites.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatRevokeInviteDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.revokeInvite"
}

@Serializable
    data class BlueCatbirdMlsChatRevokeInviteInput(
// Unique identifier for the invite to revoke        @SerialName("inviteId")
        val inviteId: String    )

    @Serializable
    data class BlueCatbirdMlsChatRevokeInviteOutput(
// Whether the revocation succeeded        @SerialName("success")
        val success: Boolean    )

sealed class BlueCatbirdMlsChatRevokeInviteError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatRevokeInviteError("Unauthorized", "Caller is not an admin of this conversation")
        object InviteNotFound: BlueCatbirdMlsChatRevokeInviteError("InviteNotFound", "Invite not found")
        object AlreadyRevoked: BlueCatbirdMlsChatRevokeInviteError("AlreadyRevoked", "Invite has already been revoked")
    }

/**
 * Revoke an existing invite link Revoke an invite link to prevent further use. Only admins can revoke invites.
 *
 * Endpoint: blue.catbird.mlsChat.revokeInvite
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.revokeInvite(
input: BlueCatbirdMlsChatRevokeInviteInput): ATProtoResponse<BlueCatbirdMlsChatRevokeInviteOutput> {
    val endpoint = "blue.catbird.mlsChat.revokeInvite"

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
