// Lexicon: 1, ID: blue.catbird.mlsChat.createInvite
// Create a new invite link for a conversation Create an invite link with optional PSK hash, expiration, and usage limits. Only admins can create invites.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatCreateInviteDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.createInvite"
}

    /**
     * View of a conversation invite with usage tracking
     */
    @Serializable
    data class BlueCatbirdMlsChatCreateInviteInviteView(
/** Unique identifier for this invite (ULID) */        @SerialName("inviteId")
        val inviteId: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** DID of admin who created this invite */        @SerialName("createdBy")
        val createdBy: DID,/** Invite creation timestamp */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** SHA-256 hash of the pre-shared key (hex-encoded) */        @SerialName("pskHash")
        val pskHash: String,/** Optional DID restriction - invite can only be used by this specific DID */        @SerialName("targetDid")
        val targetDid: DID?,/** Optional expiration timestamp */        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate?,/** Optional maximum number of uses */        @SerialName("maxUses")
        val maxUses: Int?,/** Number of times this invite has been used */        @SerialName("useCount")
        val useCount: Int,/** Whether this invite has been revoked */        @SerialName("isRevoked")
        val isRevoked: Boolean,/** Timestamp when invite was revoked (if applicable) */        @SerialName("revokedAt")
        val revokedAt: ATProtocolDate?,/** DID of admin who revoked this invite (if applicable) */        @SerialName("revokedBy")
        val revokedBy: DID?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCreateInviteInviteView"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatCreateInviteInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// SHA-256 hash of the pre-shared key (hex-encoded). Used to verify invite link authenticity without exposing PSK.        @SerialName("pskHash")
        val pskHash: String,// Optional DID restriction - invite can only be used by this specific DID        @SerialName("targetDid")
        val targetDid: DID? = null,// Optional expiration timestamp. Invite becomes invalid after this time.        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null,// Optional maximum number of times this invite can be used. Defaults to unlimited.        @SerialName("maxUses")
        val maxUses: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatCreateInviteOutput(
// Unique identifier for this invite (ULID)        @SerialName("inviteId")
        val inviteId: String,// Full invite details        @SerialName("invite")
        val invite: BlueCatbirdMlsChatCreateInviteInviteView    )

sealed class BlueCatbirdMlsChatCreateInviteError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatCreateInviteError("Unauthorized", "Caller is not an admin of this conversation")
        object InvalidPSKHash: BlueCatbirdMlsChatCreateInviteError("InvalidPSKHash", "PSK hash is invalid or malformed")
        object ConvoNotFound: BlueCatbirdMlsChatCreateInviteError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatCreateInviteError("NotMember", "Caller is not a member of this conversation")
    }

/**
 * Create a new invite link for a conversation Create an invite link with optional PSK hash, expiration, and usage limits. Only admins can create invites.
 *
 * Endpoint: blue.catbird.mlsChat.createInvite
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.createInvite(
input: BlueCatbirdMlsChatCreateInviteInput): ATProtoResponse<BlueCatbirdMlsChatCreateInviteOutput> {
    val endpoint = "blue.catbird.mlsChat.createInvite"

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
