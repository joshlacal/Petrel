// Lexicon: 1, ID: blue.catbird.mls.getPendingDeviceAdditions
// Get pending device additions for conversations (polling fallback for SSE) Returns pending device additions for conversations where caller is a member. Used as fallback when SSE events are missed.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetPendingDeviceAdditionsDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getPendingDeviceAdditions"
}

    /**
     * A pending device addition waiting to be processed
     */
    @Serializable
    data class BlueCatbirdMlsGetPendingDeviceAdditionsPendingDeviceAddition(
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
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetPendingDeviceAdditionsPendingDeviceAddition"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetPendingDeviceAdditionsParameters(
// Optional filter for specific conversation IDs. If omitted, returns all pending additions.        @SerialName("convoIds")
        val convoIds: List<String>? = null,// Maximum number of pending additions to return        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsGetPendingDeviceAdditionsOutput(
// List of pending device additions        @SerialName("pendingAdditions")
        val pendingAdditions: List<BlueCatbirdMlsGetPendingDeviceAdditionsPendingDeviceAddition>    )

sealed class BlueCatbirdMlsGetPendingDeviceAdditionsError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsGetPendingDeviceAdditionsError("Unauthorized", "Authentication required")
    }

/**
 * Get pending device additions for conversations (polling fallback for SSE) Returns pending device additions for conversations where caller is a member. Used as fallback when SSE events are missed.
 *
 * Endpoint: blue.catbird.mls.getPendingDeviceAdditions
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getPendingDeviceAdditions(
parameters: BlueCatbirdMlsGetPendingDeviceAdditionsParameters): ATProtoResponse<BlueCatbirdMlsGetPendingDeviceAdditionsOutput> {
    val endpoint = "blue.catbird.mls.getPendingDeviceAdditions"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
