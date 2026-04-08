// Lexicon: 1, ID: blue.catbird.mlsChat.getPendingDeviceAdditions
// Get pending device additions for conversations (polling fallback for SSE) Returns pending device additions for conversations where caller is a member. Used as fallback when SSE events are missed.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetPendingDeviceAdditionsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getPendingDeviceAdditions"
}

    /**
     * A pending device addition waiting to be processed
     */
    @Serializable
    data class BlueCatbirdMlsChatGetPendingDeviceAdditionsPendingDeviceAddition(
/** Unique identifier for this pending addition */        @SerialName("id")
        val id: String,/** Conversation identifier */        @SerialName("convoId")
        val convoId: String,/** Base user DID (without device suffix) */        @SerialName("userDid")
        val userDid: DID,/** Device identifier */        @SerialName("deviceId")
        val deviceId: String,/** Human-readable device name */        @SerialName("deviceName")
        val deviceName: String?,/** Full device credential DID (format: did:plc:user#device-uuid) */        @SerialName("deviceCredentialDid")
        val deviceCredentialDid: String,/** Current status of the pending addition */        @SerialName("status")
        val status: String,/** DID of the member who claimed this addition (if in_progress) */        @SerialName("claimedBy")
        val claimedBy: DID?,/** When this pending addition was created */        @SerialName("createdAt")
        val createdAt: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetPendingDeviceAdditionsPendingDeviceAddition"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatGetPendingDeviceAdditionsParameters(
// Optional filter for specific conversation IDs. If omitted, returns all pending additions.        @SerialName("convoIds")
        val convoIds: List<String>? = null,// Maximum number of pending additions to return        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetPendingDeviceAdditionsOutput(
// List of pending device additions        @SerialName("pendingAdditions")
        val pendingAdditions: List<BlueCatbirdMlsChatGetPendingDeviceAdditionsPendingDeviceAddition>    )

sealed class BlueCatbirdMlsChatGetPendingDeviceAdditionsError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatGetPendingDeviceAdditionsError("Unauthorized", "Authentication required")
    }

/**
 * Get pending device additions for conversations (polling fallback for SSE) Returns pending device additions for conversations where caller is a member. Used as fallback when SSE events are missed.
 *
 * Endpoint: blue.catbird.mlsChat.getPendingDeviceAdditions
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getPendingDeviceAdditions(
parameters: BlueCatbirdMlsChatGetPendingDeviceAdditionsParameters): ATProtoResponse<BlueCatbirdMlsChatGetPendingDeviceAdditionsOutput> {
    val endpoint = "blue.catbird.mlsChat.getPendingDeviceAdditions"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
