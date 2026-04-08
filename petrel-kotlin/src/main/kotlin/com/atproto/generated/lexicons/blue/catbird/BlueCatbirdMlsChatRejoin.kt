// Lexicon: 1, ID: blue.catbird.mlsChat.rejoin
// Request to rejoin an MLS conversation after local state loss. When a device registers and gets auto_joined_convos, it needs to request rejoin to get Welcome messages for those conversations.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatRejoinDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.rejoin"
}

@Serializable
    data class BlueCatbirdMlsChatRejoinInput(
// Conversation identifier to rejoin        @SerialName("convoId")
        val convoId: String,// Base64url-encoded fresh MLS KeyPackage for re-adding to the group        @SerialName("keyPackage")
        val keyPackage: String,// Optional reason for rejoin request        @SerialName("reason")
        val reason: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatRejoinOutput(
// Rejoin request identifier for tracking        @SerialName("requestId")
        val requestId: String,// Whether request is pending approval (true) or auto-approved (false)        @SerialName("pending")
        val pending: Boolean,// Timestamp if request was auto-approved        @SerialName("approvedAt")
        val approvedAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsChatRejoinError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatRejoinError("ConvoNotFound", "Conversation not found or user was never a member")
        object AlreadyMember: BlueCatbirdMlsChatRejoinError("AlreadyMember", "User is already an active member with valid group state")
        object InvalidKeyPackage: BlueCatbirdMlsChatRejoinError("InvalidKeyPackage", "KeyPackage is malformed, expired, or invalid")
        object RateLimitExceeded: BlueCatbirdMlsChatRejoinError("RateLimitExceeded", "Too many rejoin requests in short period")
    }

/**
 * Request to rejoin an MLS conversation after local state loss. When a device registers and gets auto_joined_convos, it needs to request rejoin to get Welcome messages for those conversations.
 *
 * Endpoint: blue.catbird.mlsChat.rejoin
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.rejoin(
input: BlueCatbirdMlsChatRejoinInput): ATProtoResponse<BlueCatbirdMlsChatRejoinOutput> {
    val endpoint = "blue.catbird.mlsChat.rejoin"

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
