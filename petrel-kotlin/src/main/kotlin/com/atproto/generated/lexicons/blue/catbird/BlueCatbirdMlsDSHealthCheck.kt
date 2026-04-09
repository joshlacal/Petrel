// Lexicon: 1, ID: blue.catbird.mlsDS.healthCheck
// Simple health/status endpoint for DS-to-DS discovery. Return the health status and federation capabilities of this delivery service. No authentication required.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSHealthCheckDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.healthCheck"
}

    @Serializable
    data class BlueCatbirdMlsDSHealthCheckOutput(
// Service DID of this delivery service        @SerialName("did")
        val did: String,// Server version        @SerialName("version")
        val version: String,// Server uptime in seconds        @SerialName("uptime")
        val uptime: Int,// List of supported federation capabilities        @SerialName("federationCapabilities")
        val federationCapabilities: List<String>    )

/**
 * Simple health/status endpoint for DS-to-DS discovery. Return the health status and federation capabilities of this delivery service. No authentication required.
 *
 * Endpoint: blue.catbird.mlsDS.healthCheck
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.healthCheck(
): ATProtoResponse<BlueCatbirdMlsDSHealthCheckOutput> {
    val endpoint = "blue.catbird.mlsDS.healthCheck"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
