// Lexicon: 1, ID: blue.catbird.mlsChat.createConvo
// Create a new MLS conversation with optional initial members, metadata, and invite link (consolidates createConvo + createInvite + revokeInvite) Create a new MLS conversation. Optionally adds initial members with a Welcome message and creates an invite link in one atomic operation.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatCreateConvoDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.createConvo"
}

    /**
     * Input metadata for conversation creation
     */
    @Serializable
    data class BlueCatbirdMlsChatCreateConvoMetadataInput(
/** Conversation display name */        @SerialName("name")
        val name: String? = null,/** Conversation description */        @SerialName("description")
        val description: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCreateConvoMetadataInput"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatCreateConvoKeyPackageHashEntry(
/** DID of the member */        @SerialName("did")
        val did: DID,/** Hex-encoded SHA-256 hash of the key package used */        @SerialName("hash")
        val hash: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCreateConvoKeyPackageHashEntry"
        }
    }

    /**
     * Invite link management sub-resource
     */
    @Serializable
    data class BlueCatbirdMlsChatCreateConvoInviteAction(
/** Action to perform: 'create' generates a new invite code, 'revoke' invalidates an existing code */        @SerialName("action")
        val action: String,/** Invite code to revoke (required when action is 'revoke') */        @SerialName("code")
        val code: String? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCreateConvoInviteAction"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatCreateConvoInput(
// Hex-encoded MLS group identifier        @SerialName("groupId")
        val groupId: String,// MLS cipher suite to use for this conversation        @SerialName("cipherSuite")
        val cipherSuite: String,// DIDs of initial members to add (max 999 excluding creator)        @SerialName("initialMembers")
        val initialMembers: List<DID>? = null,// MLS Welcome message for ALL initial members        @SerialName("welcomeMessage")
        val welcomeMessage: Bytes? = null,// Array of {did, hash} objects mapping each initial member to their key package hash        @SerialName("keyPackageHashes")
        val keyPackageHashes: List<BlueCatbirdMlsChatCreateConvoKeyPackageHashEntry>? = null,// Optional conversation metadata (name, description)        @SerialName("metadata")
        val metadata: BlueCatbirdMlsChatCreateConvoMetadataInput? = null,// Optional invite link management: create or revoke invite codes at conversation creation time        @SerialName("invite")
        val invite: BlueCatbirdMlsChatCreateConvoInviteAction? = null,// Client's current MLS epoch after group creation (for server telemetry only)        @SerialName("currentEpoch")
        val currentEpoch: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatCreateConvoOutput(
// The created conversation view        @SerialName("convo")
        val convo: BlueCatbirdMlsChatDefsConvoView,// Generated invite code (only present if invite.action was 'create')        @SerialName("inviteCode")
        val inviteCode: String? = null,// DID of the delivery service acting as sequencer for this conversation        @SerialName("sequencerDs")
        val sequencerDs: DID? = null    )

sealed class BlueCatbirdMlsChatCreateConvoError(val name: String, val description: String?) {
        object InvalidCipherSuite: BlueCatbirdMlsChatCreateConvoError("InvalidCipherSuite", "The specified cipher suite is not supported")
        object KeyPackageNotFound: BlueCatbirdMlsChatCreateConvoError("KeyPackageNotFound", "Key package not found for one or more initial members")
        object TooManyMembers: BlueCatbirdMlsChatCreateConvoError("TooManyMembers", "Too many initial members specified")
        object MutualBlockDetected: BlueCatbirdMlsChatCreateConvoError("MutualBlockDetected", "Cannot create conversation with users who have blocked each other")
    }

/**
 * Create a new MLS conversation with optional initial members, metadata, and invite link (consolidates createConvo + createInvite + revokeInvite) Create a new MLS conversation. Optionally adds initial members with a Welcome message and creates an invite link in one atomic operation.
 *
 * Endpoint: blue.catbird.mlsChat.createConvo
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.createConvo(
input: BlueCatbirdMlsChatCreateConvoInput): ATProtoResponse<BlueCatbirdMlsChatCreateConvoOutput> {
    val endpoint = "blue.catbird.mlsChat.createConvo"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
