// Lexicon: 1, ID: blue.catbird.mlsChat.getKeyPackageStatus
// Get key package statistics and status for the authenticated user's devices Retrieve key package counts, status, and history for the authenticated user. Useful for clients to know when to replenish key packages.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetKeyPackageStatusDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getKeyPackageStatus"
}

    @Serializable
    data class BlueCatbirdMlsChatGetKeyPackageStatusKeyPackageStats(
        @SerialName("totalAvailable")
        val totalAvailable: Int,        @SerialName("totalConsumed")
        val totalConsumed: Int,        @SerialName("byDevice")
        val byDevice: List<BlueCatbirdMlsChatGetKeyPackageStatusDeviceKeyPackageCount>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetKeyPackageStatusKeyPackageStats"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatGetKeyPackageStatusDeviceKeyPackageCount(
        @SerialName("deviceId")
        val deviceId: String,        @SerialName("available")
        val available: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetKeyPackageStatusDeviceKeyPackageCount"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatGetKeyPackageStatusKeyPackageStatusItem(
        @SerialName("id")
        val id: String,        @SerialName("deviceId")
        val deviceId: String,        @SerialName("cipherSuite")
        val cipherSuite: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate? = null,        @SerialName("consumed")
        val consumed: Boolean    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetKeyPackageStatusKeyPackageStatusItem"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatGetKeyPackageStatusKeyPackageHistoryItem(
        @SerialName("id")
        val id: String,        @SerialName("action")
        val action: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("consumedByDid")
        val consumedByDid: DID? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetKeyPackageStatusKeyPackageHistoryItem"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatGetKeyPackageStatusParameters(
// DID to check status for (defaults to authenticated user)        @SerialName("did")
        val did: DID? = null,// Filter by cipher suite        @SerialName("cipherSuite")
        val cipherSuite: String? = null,// Comma-separated sections to include        @SerialName("include")
        val include: String? = null,// Maximum results for status/history sections        @SerialName("limit")
        val limit: Int? = null,// Pagination cursor        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetKeyPackageStatusOutput(
        @SerialName("stats")
        val stats: BlueCatbirdMlsChatGetKeyPackageStatusKeyPackageStats? = null,        @SerialName("status")
        val status: List<BlueCatbirdMlsChatGetKeyPackageStatusKeyPackageStatusItem>? = null,        @SerialName("history")
        val history: List<BlueCatbirdMlsChatGetKeyPackageStatusKeyPackageHistoryItem>? = null,        @SerialName("cursor")
        val cursor: String? = null    )

/**
 * Get key package statistics and status for the authenticated user's devices Retrieve key package counts, status, and history for the authenticated user. Useful for clients to know when to replenish key packages.
 *
 * Endpoint: blue.catbird.mlsChat.getKeyPackageStatus
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getKeyPackageStatus(
parameters: BlueCatbirdMlsChatGetKeyPackageStatusParameters): ATProtoResponse<BlueCatbirdMlsChatGetKeyPackageStatusOutput> {
    val endpoint = "blue.catbird.mlsChat.getKeyPackageStatus"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
