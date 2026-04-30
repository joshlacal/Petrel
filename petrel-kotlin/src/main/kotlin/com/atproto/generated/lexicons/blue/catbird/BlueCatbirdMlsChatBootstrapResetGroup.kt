// Lexicon: 1, ID: blue.catbird.mlsChat.bootstrapResetGroup
// Complete a post-auto-reset conversation by populating its emptied MLS state (group_info, welcome messages). The post-reset row exists with id=originalConvoId, group_id=newGroupId, and group_info=NULL — this endpoint UPDATEs that row in place rather than INSERTing a new conversation. First caller (in the existing member roster) for a given (originalConvoId, newGroupId) wins; later callers receive AlreadyBootstrapped 409 and fall back to receiving the Welcome from the winner. Bootstrap a post-auto-reset conversation in place. Member roster is preserved across reset, so this endpoint does not re-insert members.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatBootstrapResetGroupDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.bootstrapResetGroup"
}

    /**
     * Maps a member DID to the SHA-256 hash of the key package consumed to wrap their Welcome.
     */
    @Serializable
    data class BlueCatbirdMlsChatBootstrapResetGroupKeyPackageHashEntry(
/** DID of the member */        @SerialName("did")
        val did: DID,/** Hex-encoded SHA-256 hash of the key package used */        @SerialName("hash")
        val hash: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatBootstrapResetGroupKeyPackageHashEntry"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatBootstrapResetGroupInput(
// Stable conversation id (unchanged across resets). Matches conversations.id.        @SerialName("originalConvoId")
        val originalConvoId: String,// Hex-encoded post-reset MLS group id. Must match the conversations.group_id value set by the auto-reset that emitted the groupResetEvent.        @SerialName("newGroupId")
        val newGroupId: String,// MLS cipher suite for the new group        @SerialName("cipherSuite")
        val cipherSuite: String,// Encoded MLS GroupInfo for the new group at epoch 1        @SerialName("groupInfo")
        val groupInfo: Bytes,// DIDs of the bootstrapped roster (typically read from getConvos pre-bootstrap). Sent for diagnostic/audit purposes; server uses the persisted members table (preserved across reset) as the authoritative roster.        @SerialName("members")
        val members: List<DID>,// MLS Welcome envelope for ALL members. Stored per-recipient based on keyPackageHashes.        @SerialName("welcomeMessage")
        val welcomeMessage: Bytes? = null,// Per-member key package hashes used in the Welcome        @SerialName("keyPackageHashes")
        val keyPackageHashes: List<BlueCatbirdMlsChatBootstrapResetGroupKeyPackageHashEntry>? = null,// Bootstrap epoch (always 1 — fresh group at epoch 1). Sent for telemetry; server hard-sets current_epoch = 1.        @SerialName("currentEpoch")
        val currentEpoch: Int? = null,// Optional locator for encrypted group metadata re-published for newGroupId. The blob itself is uploaded through putGroupMetadataBlob; this field lets clients declare the locator used by the reset winner.        @SerialName("metadataBlobLocator")
        val metadataBlobLocator: String? = null,// Optional encrypted metadata version associated with metadataBlobLocator.        @SerialName("metadataVersion")
        val metadataVersion: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatBootstrapResetGroupOutput(
// The now-bootstrapped conversation view, including the preserved member roster        @SerialName("convo")
        val convo: BlueCatbirdMlsChatDefsConvoView,// Generation number of the now-active crypto_session (preserved across self-heal; freshly minted across activate). Clients seed pendingResetGeneration with this value on bootstrap success so subsequent SSE replay events carrying a stale `gen` are short-circuited before destructive recovery (e.g. deleteGroup) fires. Optional for backward compatibility — older clients that miss the field fall back to fetching it via getConversation/getGroupState.        @SerialName("generation")
        val generation: Int? = null    )

sealed class BlueCatbirdMlsChatBootstrapResetGroupError(val name: String, val description: String?) {
        object BootstrapTargetNotFound: BlueCatbirdMlsChatBootstrapResetGroupError("BootstrapTargetNotFound", "No conversation row matches (originalConvoId, newGroupId). Either the convo doesn't exist, or the post-reset group_id has already been overwritten by a subsequent reset.")
        object AlreadyBootstrapped: BlueCatbirdMlsChatBootstrapResetGroupError("AlreadyBootstrapped", "The post-reset row has already been bootstrapped by another caller (group_info IS NOT NULL). Caller lost the first-responder race; fall back to receiving the Welcome from the winner.")
        object NotMember: BlueCatbirdMlsChatBootstrapResetGroupError("NotMember", "Caller is not in the existing member roster for this convo and so is not allowed to bootstrap it.")
        object InvalidCipherSuite: BlueCatbirdMlsChatBootstrapResetGroupError("InvalidCipherSuite", "The specified cipher suite is not supported.")
    }

/**
 * Complete a post-auto-reset conversation by populating its emptied MLS state (group_info, welcome messages). The post-reset row exists with id=originalConvoId, group_id=newGroupId, and group_info=NULL — this endpoint UPDATEs that row in place rather than INSERTing a new conversation. First caller (in the existing member roster) for a given (originalConvoId, newGroupId) wins; later callers receive AlreadyBootstrapped 409 and fall back to receiving the Welcome from the winner. Bootstrap a post-auto-reset conversation in place. Member roster is preserved across reset, so this endpoint does not re-insert members.
 *
 * Endpoint: blue.catbird.mlsChat.bootstrapResetGroup
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.bootstrapResetGroup(
input: BlueCatbirdMlsChatBootstrapResetGroupInput): ATProtoResponse<BlueCatbirdMlsChatBootstrapResetGroupOutput> {
    val endpoint = "blue.catbird.mlsChat.bootstrapResetGroup"

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
