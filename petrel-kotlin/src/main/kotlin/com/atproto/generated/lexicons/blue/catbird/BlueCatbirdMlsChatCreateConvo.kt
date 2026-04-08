// Lexicon: 1, ID: blue.catbird.mlsChat.createConvo
// Create a new MLS conversation with optional initial members and metadata Create a new MLS conversation
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
     * Input metadata for conversation creation (text-only, no avatar)
     */
    @Serializable
    data class BlueCatbirdMlsChatCreateConvoMetadataInput(
/** Conversation display name */        @SerialName("name")
        val name: String?,/** Conversation description */        @SerialName("description")
        val description: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCreateConvoMetadataInput"
        }
    }

    /**
     * Maps a DID to the key package hash used for their Welcome message
     */
    @Serializable
    data class BlueCatbirdMlsChatCreateConvoKeyPackageHashEntry(
/** DID of the member */        @SerialName("did")
        val did: DID,/** Hex-encoded SHA-256 hash of the key package used */        @SerialName("hash")
        val hash: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatCreateConvoKeyPackageHashEntry"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatCreateConvoInput(
// Hex-encoded MLS group identifier        @SerialName("groupId")
        val groupId: String,// Client-generated UUID for idempotent request retries. Optional but recommended.        @SerialName("idempotencyKey")
        val idempotencyKey: String? = null,// MLS cipher suite to use for this conversation        @SerialName("cipherSuite")
        val cipherSuite: String,// DIDs of initial members to add to the conversation (max 999 excluding creator, default policy allows up to 1000 total)        @SerialName("initialMembers")
        val initialMembers: List<DID>? = null,// Base64url-encoded MLS Welcome message containing encrypted secrets for ALL initial members        @SerialName("welcomeMessage")
        val welcomeMessage: String? = null,// Array of {did, hash} objects mapping each initial member to their key package hash. Required for multi-device support.        @SerialName("keyPackageHashes")
        val keyPackageHashes: List<BlueCatbirdMlsChatCreateConvoKeyPackageHashEntry>? = null,// Optional conversation metadata (name, description, avatar)        @SerialName("metadata")
        val metadata: BlueCatbirdMlsChatCreateConvoMetadataInput? = null,// Client's current MLS epoch after group creation and adding initial members. Used for server telemetry only (server is not authoritative for MLS state). Defaults to 0 if not provided.        @SerialName("currentEpoch")
        val currentEpoch: Int? = null    )

    typealias BlueCatbirdMlsChatCreateConvoOutput = BlueCatbirdMlsChatDefsConvoView

sealed class BlueCatbirdMlsChatCreateConvoError(val name: String, val description: String?) {
        object InvalidCipherSuite: BlueCatbirdMlsChatCreateConvoError("InvalidCipherSuite", "The specified cipher suite is not supported")
        object KeyPackageNotFound: BlueCatbirdMlsChatCreateConvoError("KeyPackageNotFound", "Key package not found for one or more initial members")
        object TooManyMembers: BlueCatbirdMlsChatCreateConvoError("TooManyMembers", "Too many initial members specified (default max 1000 total including creator, configurable per-conversation via policy)")
        object MutualBlockDetected: BlueCatbirdMlsChatCreateConvoError("MutualBlockDetected", "Cannot create conversation with users who have blocked each other on Bluesky")
    }

/**
 * Create a new MLS conversation with optional initial members and metadata Create a new MLS conversation
 *
 * Endpoint: blue.catbird.mlsChat.createConvo
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.createConvo(
input: BlueCatbirdMlsChatCreateConvoInput): ATProtoResponse<BlueCatbirdMlsChatCreateConvoOutput> {
    val endpoint = "blue.catbird.mlsChat.createConvo"

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
