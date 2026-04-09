// Lexicon: 1, ID: blue.catbird.mlsChat.getBlobUsage
// Get blob storage usage for the authenticated user Returns the authenticated user's current blob storage usage, quota, and blob count.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetBlobUsageDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getBlobUsage"
}

    @Serializable
    data class BlueCatbirdMlsChatGetBlobUsageOutput(
// Total bytes used by the user's active blobs        @SerialName("usedBytes")
        val usedBytes: Int,// Maximum allowed bytes (500MB)        @SerialName("quotaBytes")
        val quotaBytes: Int,// Number of active blobs        @SerialName("blobCount")
        val blobCount: Int    )

/**
 * Get blob storage usage for the authenticated user Returns the authenticated user's current blob storage usage, quota, and blob count.
 *
 * Endpoint: blue.catbird.mlsChat.getBlobUsage
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getBlobUsage(
): ATProtoResponse<BlueCatbirdMlsChatGetBlobUsageOutput> {
    val endpoint = "blue.catbird.mlsChat.getBlobUsage"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
