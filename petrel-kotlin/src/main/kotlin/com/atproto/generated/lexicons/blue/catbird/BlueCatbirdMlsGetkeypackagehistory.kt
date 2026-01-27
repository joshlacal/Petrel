// Lexicon: 1, ID: blue.catbird.mls.getKeyPackageHistory
// Get key package consumption history for the authenticated user
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetKeyPackageHistoryDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getKeyPackageHistory"
}

    @Serializable
    data class BlueCatbirdMlsGetKeyPackageHistoryKeyPackageHistoryEntry(
/** Key package hash identifier */        @SerialName("packageId")
        val packageId: String,/** When the key package was created */        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** When the key package was consumed */        @SerialName("consumedAt")
        val consumedAt: ATProtocolDate?,/** Conversation ID where package was consumed */        @SerialName("consumedForConvo")
        val consumedForConvo: String?,/** Name of the conversation where package was consumed */        @SerialName("consumedForConvoName")
        val consumedForConvoName: String?,/** Device ID that initiated the add operation */        @SerialName("consumedByDevice")
        val consumedByDevice: String?,/** Device ID that owns this key package */        @SerialName("deviceId")
        val deviceId: String?,/** MLS cipher suite identifier */        @SerialName("cipherSuite")
        val cipherSuite: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetKeyPackageHistoryKeyPackageHistoryEntry"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetKeyPackageHistoryParameters(
// Maximum number of history entries to return        @SerialName("limit")
        val limit: Int? = null,// Pagination cursor from previous response        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class BlueCatbirdMlsGetKeyPackageHistoryOutput(
        @SerialName("history")
        val history: List<BlueCatbirdMlsGetKeyPackageHistoryKeyPackageHistoryEntry>,// Cursor for pagination; present if more results available        @SerialName("cursor")
        val cursor: String? = null    )

/**
 * Get key package consumption history for the authenticated user
 *
 * Endpoint: blue.catbird.mls.getKeyPackageHistory
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getKeyPackageHistory(
parameters: BlueCatbirdMlsGetKeyPackageHistoryParameters): ATProtoResponse<BlueCatbirdMlsGetKeyPackageHistoryOutput> {
    val endpoint = "blue.catbird.mls.getKeyPackageHistory"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
