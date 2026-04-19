// Lexicon: 1, ID: blue.catbird.mlsChat.commitGroupChange
// Commit MLS group membership changes (consolidates addMembers + processExternalCommit + rejoin + readdition + getPendingDeviceAdditions + claimPendingDeviceAddition + completePendingDeviceAddition) Perform MLS group membership operations. The 'action' field determines the operation type. This consolidates all membership-changing operations into a single endpoint.
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

    @Serializable
    data class BlueCatbirdMlsChatCommitGroupChangeKeyPackageHashEntry(
/** DID of the member */        @SerialName("did")
        val did: DID,/** Hex-encoded SHA-256 hash of the key package used */        @SerialName("hash")
        val hash: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCommitGroupChangeKeyPackageHashEntry"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatCommitGroupChangePendingDeviceAddition(
/** Unique identifier for this pending addition */        @SerialName("id")
        val id: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Base user DID (without device suffix) */        @SerialName("userDid")
        val userDid: DID,/** Device identifier */        @SerialName("deviceId")
        val deviceId: String,/** Human-readable device name */        @SerialName("deviceName")
        val deviceName: String? = null,/** Full device credential DID (format: did:plc:user#device-uuid) */        @SerialName("deviceCredentialDid")
        val deviceCredentialDid: String,/** Current status of the pending addition */        @SerialName("status")
        val status: String,/** DID of the member who claimed this addition (if in_progress) */        @SerialName("claimedBy")
        val claimedBy: DID? = null,/** When this pending addition was created */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCommitGroupChangePendingDeviceAddition"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatCommitGroupChangeInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Membership action to perform        @SerialName("action")
        val action: String,// DIDs of members to add (required for 'addMembers')        @SerialName("memberDids")
        val memberDids: List<DID>? = null,// MLS Commit message (used by addMembers, processExternalCommit, rejoin)        @SerialName("commit")
        val commit: Bytes? = null,// MLS Welcome message (used by addMembers, completePendingDeviceAddition)        @SerialName("welcome")
        val welcome: Bytes? = null,// GroupInfo to update after commit (used by processExternalCommit, addMembers)        @SerialName("groupInfo")
        val groupInfo: Bytes? = null,// Key package hash mappings for new members (used by addMembers, completePendingDeviceAddition)        @SerialName("keyPackageHashes")
        val keyPackageHashes: List<BlueCatbirdMlsChatCommitGroupChangeKeyPackageHashEntry>? = null,// Device ID for pending device addition operations (used by claimPendingDeviceAddition)        @SerialName("deviceId")
        val deviceId: String? = null,// ID of the pending addition to claim or complete        @SerialName("pendingAdditionId")
        val pendingAdditionId: String? = null,// Client-generated UUID for idempotent retries        @SerialName("idempotencyKey")
        val idempotencyKey: String? = null,// MLS confirmation tag from the client's post-commit group state.        @SerialName("confirmationTag")
        val confirmationTag: Bytes? = null,// Hex-encoded epoch_authenticator (RFC 9420 §8.7) for the post-commit epoch. Optional. When present on an epoch-advancing action (addMembers, processExternalCommit, rejoin, commit, updateMetadata), the server records it in the epoch_authenticators table and uses it to validate future reportRecoveryFailure votes for quorum auto-reset (see ADR-002).        @SerialName("epochAuthenticator")
        val epochAuthenticator: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatCommitGroupChangeOutput(
// Whether the operation succeeded        @SerialName("success")
        val success: Boolean,// New epoch number after the change (for addMembers, processExternalCommit, rejoin)        @SerialName("newEpoch")
        val newEpoch: Int? = null,// Timestamp of rejoin (for processExternalCommit, rejoin)        @SerialName("rejoinedAt")
        val rejoinedAt: ATProtocolDate? = null,// List of pending device additions (for getPendingDeviceAdditions)        @SerialName("pendingAdditions")
        val pendingAdditions: List<BlueCatbirdMlsChatCommitGroupChangePendingDeviceAddition>? = null,// The claimed pending addition (for claimPendingDeviceAddition)        @SerialName("claimedAddition")
        val claimedAddition: BlueCatbirdMlsChatCommitGroupChangePendingDeviceAddition? = null,// confirmation tag of the new canonical tree state.        @SerialName("confirmationTag")
        val confirmationTag: Bytes? = null    )

sealed class BlueCatbirdMlsChatCommitGroupChangeError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatCommitGroupChangeError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatCommitGroupChangeError("NotMember", "Caller is not a member of the conversation")
        object InvalidAction: BlueCatbirdMlsChatCommitGroupChangeError("InvalidAction", "Unknown action value")
        object KeyPackageNotFound: BlueCatbirdMlsChatCommitGroupChangeError("KeyPackageNotFound", "Key package not found for one or more members")
        object AlreadyMember: BlueCatbirdMlsChatCommitGroupChangeError("AlreadyMember", "One or more DIDs are already members")
        object TooManyMembers: BlueCatbirdMlsChatCommitGroupChangeError("TooManyMembers", "Would exceed maximum member count")
        object BlockedByMember: BlueCatbirdMlsChatCommitGroupChangeError("BlockedByMember", "Cannot add user who has blocked or been blocked by an existing member")
        object InvalidCommit: BlueCatbirdMlsChatCommitGroupChangeError("InvalidCommit", "The provided MLS Commit message is invalid")
        object InvalidGroupInfo: BlueCatbirdMlsChatCommitGroupChangeError("InvalidGroupInfo", "The provided GroupInfo is invalid")
        object PendingAdditionNotFound: BlueCatbirdMlsChatCommitGroupChangeError("PendingAdditionNotFound", "The specified pending addition does not exist")
        object PendingAdditionAlreadyClaimed: BlueCatbirdMlsChatCommitGroupChangeError("PendingAdditionAlreadyClaimed", "The pending addition was already claimed by another member")
        object Unauthorized: BlueCatbirdMlsChatCommitGroupChangeError("Unauthorized", "Insufficient privileges for this operation")
    }

/**
 * Commit MLS group membership changes (consolidates addMembers + processExternalCommit + rejoin + readdition + getPendingDeviceAdditions + claimPendingDeviceAddition + completePendingDeviceAddition) Perform MLS group membership operations. The 'action' field determines the operation type. This consolidates all membership-changing operations into a single endpoint.
 *
 * Endpoint: blue.catbird.mlsChat.commitGroupChange
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.commitGroupChange(
input: BlueCatbirdMlsChatCommitGroupChangeInput): ATProtoResponse<BlueCatbirdMlsChatCommitGroupChangeOutput> {
    val endpoint = "blue.catbird.mlsChat.commitGroupChange"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
