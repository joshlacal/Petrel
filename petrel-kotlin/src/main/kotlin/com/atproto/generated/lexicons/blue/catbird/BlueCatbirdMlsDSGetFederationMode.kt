// Lexicon: 1, ID: blue.catbird.mlsDS.getFederationMode
// Get the current federation mode (admin only). Return the effective, override, and environment federation mode settings.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSGetFederationModeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.getFederationMode"
}

    @Serializable
    data class BlueCatbirdMlsDSGetFederationModeOutput(
// Currently effective federation mode        @SerialName("effectiveMode")
        val effectiveMode: String,// Runtime override mode (if set)        @SerialName("overrideMode")
        val overrideMode: String? = null,// Federation mode from environment configuration        @SerialName("envMode")
        val envMode: String    )

/**
 * Get the current federation mode (admin only). Return the effective, override, and environment federation mode settings.
 *
 * Endpoint: blue.catbird.mlsDS.getFederationMode
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.getFederationMode(
): ATProtoResponse<BlueCatbirdMlsDSGetFederationModeOutput> {
    val endpoint = "blue.catbird.mlsDS.getFederationMode"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
