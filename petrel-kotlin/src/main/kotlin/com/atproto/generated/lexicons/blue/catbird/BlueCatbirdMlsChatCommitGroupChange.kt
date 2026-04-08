// Lexicon: 1, ID: blue.catbird.mlsChat.commitGroupChange
// Commit an MLS group change (add members, process external commit, rejoin, readdition, or manage pending device additions)
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatCommitGroupChangeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.commitGroupChange"
}

    /**
     * A pending device addition waiting to be claimed and completed
     */
    @Serializable
    data class BlueCatbirdMlsChatCommitGroupChangePendingDeviceAddition(
/** Unique identifier for the pending addition */        @SerialName("id")
        val id: String,/** Conversation the device is being added to */        @SerialName("convoId")
        val convoId: String,/** User DID who owns the device */        @SerialName("userDid")
        val userDid: DID,/** Device identifier */        @SerialName("deviceId")
        val deviceId: String,/** Full device credential DID */        @SerialName("deviceCredentialDid")
        val deviceCredentialDid: String?,/** When the pending addition was created */        @SerialName("createdAt")
        val createdAt: ATProtocolDate?,/** DID of the device that claimed this addition */        @SerialName("claimedBy")
        val claimedBy: DID?,/** When the addition was claimed */        @SerialName("claimedAt")
        val claimedAt: ATProtocolDate?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCommitGroupChangePendingDeviceAddition"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatCommitGroupChangeInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Group change action to perform        @SerialName("action")
        val action: String,// DIDs of members to add (for addMembers action)        @SerialName("memberDids")
        val memberDids: List<String>? = null,// MLS commit message bytes        @SerialName("commit")
        val commit: ByteArray? = null,// MLS welcome message bytes        @SerialName("welcome")
        val welcome: ByteArray? = null,// MLS group info bytes        @SerialName("groupInfo")
        val groupInfo: ByteArray? = null,// MLS external commit bytes        @SerialName("externalCommit")
        val externalCommit: ByteArray? = null,// Base64 encoded confirmation tag        @SerialName("confirmationTag")
        val confirmationTag: String? = null,// Client-generated UUID for idempotent request retries        @SerialName("idempotencyKey")
        val idempotencyKey: String? = null,// ID of the pending addition to claim (for claimPending action)        @SerialName("pendingAdditionId")
        val pendingAdditionId: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatCommitGroupChangeOutput(
// Whether the group change was successfully committed        @SerialName("success")
        val success: Boolean,// New epoch number after the change        @SerialName("newEpoch")
        val newEpoch: Int? = null,// Base64 encoded confirmation tag from the commit        @SerialName("confirmationTag")
        val confirmationTag: String? = null,// Details of the claimed pending addition (for claimPending action)        @SerialName("claimedAddition")
        val claimedAddition: BlueCatbirdMlsChatCommitGroupChangePendingDeviceAddition? = null,// List of pending device additions (for listPending action)        @SerialName("pendingAdditions")
        val pendingAdditions: List<BlueCatbirdMlsChatCommitGroupChangePendingDeviceAddition>? = null,// Timestamp when the rejoin was processed        @SerialName("rejoinedAt")
        val rejoinedAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsChatCommitGroupChangeError(val name: String, val description: String?) {
        object InvalidRequest: BlueCatbirdMlsChatCommitGroupChangeError("InvalidRequest", "Invalid request parameters")
        object AuthRequired: BlueCatbirdMlsChatCommitGroupChangeError("AuthRequired", "Authentication required")
        object Forbidden: BlueCatbirdMlsChatCommitGroupChangeError("Forbidden", "User does not have permission for this action")
        object Conflict: BlueCatbirdMlsChatCommitGroupChangeError("Conflict", "Conflicting group state (e.g., epoch mismatch)")
    }

/**
 * Commit an MLS group change (add members, process external commit, rejoin, readdition, or manage pending device additions)
 *
 * Endpoint: blue.catbird.mlsChat.commitGroupChange
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.commitGroupChange(
input: BlueCatbirdMlsChatCommitGroupChangeInput): ATProtoResponse<BlueCatbirdMlsChatCommitGroupChangeOutput> {
    val endpoint = "blue.catbird.mlsChat.commitGroupChange"

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
