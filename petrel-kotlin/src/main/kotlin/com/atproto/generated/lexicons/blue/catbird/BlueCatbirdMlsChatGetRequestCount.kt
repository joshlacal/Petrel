// Lexicon: 1, ID: blue.catbird.mlsChat.getRequestCount
// Get count of pending chat requests for badge display Returns the count of pending chat requests. Lightweight endpoint for badge updates.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetRequestCountDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getRequestCount"
}

    @Serializable
    data class BlueCatbirdMlsChatGetRequestCountOutput(
// Number of pending requests        @SerialName("pendingCount")
        val pendingCount: Int,// Timestamp of most recent pending request        @SerialName("lastRequestAt")
        val lastRequestAt: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsChatGetRequestCountError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatGetRequestCountError("Unauthorized", "Authentication required")
    }

/**
 * Get count of pending chat requests for badge display Returns the count of pending chat requests. Lightweight endpoint for badge updates.
 *
 * Endpoint: blue.catbird.mlsChat.getRequestCount
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getRequestCount(
): ATProtoResponse<BlueCatbirdMlsChatGetRequestCountOutput> {
    val endpoint = "blue.catbird.mlsChat.getRequestCount"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
