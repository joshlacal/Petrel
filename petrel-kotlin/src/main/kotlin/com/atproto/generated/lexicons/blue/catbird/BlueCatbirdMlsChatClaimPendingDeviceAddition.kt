// Lexicon: 1, ID: blue.catbird.mlsChat.claimPendingDeviceAddition
// Atomically claim a pending device addition to prevent race conditions Claims a pending device addition so only one member processes it. Claim expires after 60 seconds if not completed. Returns claimed=false with no convoId if pending addition not found or already completed.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatClaimPendingDeviceAdditionDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.claimPendingDeviceAddition"
}

@Serializable
    data class BlueCatbirdMlsChatClaimPendingDeviceAdditionInput(
// ID of the pending addition to claim        @SerialName("pendingAdditionId")
        val pendingAdditionId: String    )

    @Serializable
    data class BlueCatbirdMlsChatClaimPendingDeviceAdditionOutput(
// True if claim was successful, false if already claimed by another or not found/completed        @SerialName("claimed")
        val claimed: Boolean,// Conversation ID (returned on successful claim or if already claimed by another)        @SerialName("convoId")
        val convoId: String? = null,// Full device credential DID to add (returned on successful claim or if already claimed)        @SerialName("deviceCredentialDid")
        val deviceCredentialDid: String? = null,// Key package for the new device (returned on successful claim)        @SerialName("keyPackage")
        val keyPackage: BlueCatbirdMlsChatDefsKeyPackageRef? = null,// DID of the member who has the claim (returned when claimed=false and another member has it)        @SerialName("claimedBy")
        val claimedBy: DID? = null    )

sealed class BlueCatbirdMlsChatClaimPendingDeviceAdditionError(val name: String, val description: String?) {
        object NotMember: BlueCatbirdMlsChatClaimPendingDeviceAdditionError("NotMember", "Caller is not a member of the conversation")
    }

/**
 * Atomically claim a pending device addition to prevent race conditions Claims a pending device addition so only one member processes it. Claim expires after 60 seconds if not completed. Returns claimed=false with no convoId if pending addition not found or already completed.
 *
 * Endpoint: blue.catbird.mlsChat.claimPendingDeviceAddition
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.claimPendingDeviceAddition(
input: BlueCatbirdMlsChatClaimPendingDeviceAdditionInput): ATProtoResponse<BlueCatbirdMlsChatClaimPendingDeviceAdditionOutput> {
    val endpoint = "blue.catbird.mlsChat.claimPendingDeviceAddition"

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
