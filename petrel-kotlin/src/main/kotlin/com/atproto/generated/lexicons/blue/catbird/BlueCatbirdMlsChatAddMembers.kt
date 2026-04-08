// Lexicon: 1, ID: blue.catbird.mlsChat.addMembers
// Add new members to an existing MLS conversation Add members to an existing MLS conversation
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatAddMembersDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.addMembers"
}

    /**
     * Maps a DID to the key package hash used for their Welcome message
     */
    @Serializable
    data class BlueCatbirdMlsChatAddMembersKeyPackageHashEntry(
/** DID of the member */        @SerialName("did")
        val did: DID,/** Hex-encoded SHA-256 hash of the key package used */        @SerialName("hash")
        val hash: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatAddMembersKeyPackageHashEntry"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatAddMembersInput(
// Conversation identifier        @SerialName("convoId")
        val convoId: String,// Client-generated UUID for idempotent request retries. Optional but recommended.        @SerialName("idempotencyKey")
        val idempotencyKey: String? = null,// DIDs of members to add        @SerialName("didList")
        val didList: List<DID>,// Optional base64url-encoded MLS Commit message        @SerialName("commit")
        val commit: String? = null,// Base64url-encoded MLS Welcome message containing encrypted secrets for ALL new members        @SerialName("welcomeMessage")
        val welcomeMessage: String? = null,// Array of {did, hash} objects mapping each new member to their key package hash. Required for multi-device support.        @SerialName("keyPackageHashes")
        val keyPackageHashes: List<BlueCatbirdMlsChatAddMembersKeyPackageHashEntry>? = null    )

    @Serializable
    data class BlueCatbirdMlsChatAddMembersOutput(
// Whether the operation succeeded        @SerialName("success")
        val success: Boolean,// New epoch number after adding members        @SerialName("newEpoch")
        val newEpoch: Int    )

sealed class BlueCatbirdMlsChatAddMembersError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatAddMembersError("ConvoNotFound", "Conversation not found")
        object NotMember: BlueCatbirdMlsChatAddMembersError("NotMember", "Caller is not a member of the conversation")
        object KeyPackageNotFound: BlueCatbirdMlsChatAddMembersError("KeyPackageNotFound", "Key package not found for one or more members")
        object AlreadyMember: BlueCatbirdMlsChatAddMembersError("AlreadyMember", "One or more DIDs are already members")
        object TooManyMembers: BlueCatbirdMlsChatAddMembersError("TooManyMembers", "Would exceed maximum member count")
        object BlockedByMember: BlueCatbirdMlsChatAddMembersError("BlockedByMember", "Cannot add user who has blocked or been blocked by an existing member (Bluesky social graph enforcement)")
    }

/**
 * Add new members to an existing MLS conversation Add members to an existing MLS conversation
 *
 * Endpoint: blue.catbird.mlsChat.addMembers
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.addMembers(
input: BlueCatbirdMlsChatAddMembersInput): ATProtoResponse<BlueCatbirdMlsChatAddMembersOutput> {
    val endpoint = "blue.catbird.mlsChat.addMembers"

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
