// Lexicon: 1, ID: blue.catbird.mlsDS.setFederationMode
// Set the federation mode at runtime (admin only). Set a runtime override for the federation mode. Requires federation admin privileges.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDSSetFederationModeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsDS.setFederationMode"
}

@Serializable
    data class BlueCatbirdMlsDSSetFederationModeInput(
// Federation mode to set (e.g., 'off', 'allowlist', 'open')        @SerialName("mode")
        val mode: String    )

    @Serializable
    data class BlueCatbirdMlsDSSetFederationModeOutput(
// Whether the mode was updated        @SerialName("updated")
        val updated: Boolean,// New effective federation mode        @SerialName("effectiveMode")
        val effectiveMode: String,// Runtime override mode        @SerialName("overrideMode")
        val overrideMode: String? = null,// Federation mode from environment configuration        @SerialName("envMode")
        val envMode: String    )

/**
 * Set the federation mode at runtime (admin only). Set a runtime override for the federation mode. Requires federation admin privileges.
 *
 * Endpoint: blue.catbird.mlsDS.setFederationMode
 */
suspend fun ATProtoClient.Blue.Catbird.MlsDS.setFederationMode(
input: BlueCatbirdMlsDSSetFederationModeInput): ATProtoResponse<BlueCatbirdMlsDSSetFederationModeOutput> {
    val endpoint = "blue.catbird.mlsDS.setFederationMode"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
