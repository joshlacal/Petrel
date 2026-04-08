// Lexicon: 1, ID: blue.catbird.mls.rejoin
// Request to rejoin an MLS conversation after local state loss. When a device registers and gets auto_joined_convos, it needs to request rejoin to get Welcome messages for those conversations.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsRejoinDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.rejoin"
}

@Serializable
    data class BlueCatbirdMlsRejoinInput(
// Conversation identifier to rejoin        @SerialName("convoId")
        val convoId: String,// Base64url-encoded fresh MLS KeyPackage for re-adding to the group        @SerialName("keyPackage")
        val keyPackage: String,// Optional reason for rejoin request        @SerialName("reason")
        val reason: String? = null    )

    @Serializable
    data class BlueCatbirdMlsRejoinOutput(
// Rejoin request identifier for tracking        @SerialName("requestId")
        val requestId: String,// Whether request is pending approval (true) or auto-approved (false)        @SerialName("pending")
        val pending: Boolean,// Timestamp if request was auto-approved        @SerialName("approvedAt")
        val approvedAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsRejoinError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsRejoinError("ConvoNotFound", "Conversation not found or user was never a member")
        object AlreadyMember: BlueCatbirdMlsRejoinError("AlreadyMember", "User is already an active member with valid group state")
        object InvalidKeyPackage: BlueCatbirdMlsRejoinError("InvalidKeyPackage", "KeyPackage is malformed, expired, or invalid")
        object RateLimitExceeded: BlueCatbirdMlsRejoinError("RateLimitExceeded", "Too many rejoin requests in short period")
    }

/**
 * Request to rejoin an MLS conversation after local state loss. When a device registers and gets auto_joined_convos, it needs to request rejoin to get Welcome messages for those conversations.
 *
 * Endpoint: blue.catbird.mls.rejoin
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.rejoin(
input: BlueCatbirdMlsRejoinInput): ATProtoResponse<BlueCatbirdMlsRejoinOutput> {
    val endpoint = "blue.catbird.mls.rejoin"

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
