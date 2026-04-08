// Lexicon: 1, ID: blue.catbird.mls.getRequestCount
// Get count of pending chat requests for badge display Returns the count of pending chat requests. Lightweight endpoint for badge updates.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetRequestCountDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getRequestCount"
}

    @Serializable
    data class BlueCatbirdMlsGetRequestCountOutput(
// Number of pending requests        @SerialName("pendingCount")
        val pendingCount: Int,// Timestamp of most recent pending request        @SerialName("lastRequestAt")
        val lastRequestAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsGetRequestCountError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsGetRequestCountError("Unauthorized", "Authentication required")
    }

/**
 * Get count of pending chat requests for badge display Returns the count of pending chat requests. Lightweight endpoint for badge updates.
 *
 * Endpoint: blue.catbird.mls.getRequestCount
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getRequestCount(
): ATProtoResponse<BlueCatbirdMlsGetRequestCountOutput> {
    val endpoint = "blue.catbird.mls.getRequestCount"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
