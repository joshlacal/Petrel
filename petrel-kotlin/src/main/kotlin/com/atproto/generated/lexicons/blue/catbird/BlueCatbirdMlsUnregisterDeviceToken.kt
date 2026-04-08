// Lexicon: 1, ID: blue.catbird.mls.unregisterDeviceToken
// Remove a device push token.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsUnregisterDeviceTokenDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.unregisterDeviceToken"
}

@Serializable
    data class BlueCatbirdMlsUnregisterDeviceTokenInput(
        @SerialName("deviceId")
        val deviceId: String    )

    @Serializable
    data class BlueCatbirdMlsUnregisterDeviceTokenOutput(
        @SerialName("success")
        val success: Boolean    )

/**
 * Remove a device push token.
 *
 * Endpoint: blue.catbird.mls.unregisterDeviceToken
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.unregisterDeviceToken(
input: BlueCatbirdMlsUnregisterDeviceTokenInput): ATProtoResponse<BlueCatbirdMlsUnregisterDeviceTokenOutput> {
    val endpoint = "blue.catbird.mls.unregisterDeviceToken"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
