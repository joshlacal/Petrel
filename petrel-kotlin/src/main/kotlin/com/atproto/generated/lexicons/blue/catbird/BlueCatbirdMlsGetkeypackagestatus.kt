// Lexicon: 1, ID: blue.catbird.mls.getKeyPackageStatus
// Get key package statistics and consumption history for the authenticated user. Helps clients detect missing bundles before processing Welcome messages.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetKeyPackageStatusDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getKeyPackageStatus"
}

    /**
     * View of a consumed key package with usage metadata
     */
    @Serializable
    data class BlueCatbirdMlsGetKeyPackageStatusConsumedPackageView(
/** SHA256 hex hash of the key package bytes */        @SerialName("keyPackageHash")
        val keyPackageHash: String,/** Group ID (hex-encoded) where this key package was consumed. May be null for historical data. */        @SerialName("usedInGroup")
        val usedInGroup: String?,/** When the key package was consumed */        @SerialName("consumedAt")
        val consumedAt: ATProtocolDate,/** Cipher suite of the consumed key package */        @SerialName("cipherSuite")
        val cipherSuite: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsGetKeyPackageStatusConsumedPackageView"
        }
    }

@Serializable
    data class BlueCatbirdMlsGetKeyPackageStatusParameters(
// Maximum number of consumed packages to return in history        @SerialName("limit")
        val limit: Int? = null,// Pagination cursor from previous response. Returns consumed packages after this cursor.        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class BlueCatbirdMlsGetKeyPackageStatusOutput(
// Total number of key packages ever uploaded by this user        @SerialName("totalUploaded")
        val totalUploaded: Int,// Number of available (unconsumed, unreserved) key packages        @SerialName("available")
        val available: Int,// Number of consumed key packages        @SerialName("consumed")
        val consumed: Int,// Number of temporarily reserved key packages (during welcome validation)        @SerialName("reserved")
        val reserved: Int? = null,// Paginated list of consumed key package history        @SerialName("consumedPackages")
        val consumedPackages: List<BlueCatbirdMlsGetKeyPackageStatusConsumedPackageView>? = null,// Cursor for fetching next page of consumed packages. Omitted if no more results.        @SerialName("cursor")
        val cursor: String? = null    )

/**
 * Get key package statistics and consumption history for the authenticated user. Helps clients detect missing bundles before processing Welcome messages.
 *
 * Endpoint: blue.catbird.mls.getKeyPackageStatus
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getKeyPackageStatus(
parameters: BlueCatbirdMlsGetKeyPackageStatusParameters): ATProtoResponse<BlueCatbirdMlsGetKeyPackageStatusOutput> {
    val endpoint = "blue.catbird.mls.getKeyPackageStatus"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
