// Lexicon: 1, ID: blue.catbird.mlsChat.unregisterDeviceToken
// Remove a device push token.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatUnregisterDeviceTokenDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.unregisterDeviceToken"
}

@Serializable
    data class BlueCatbirdMlsChatUnregisterDeviceTokenInput(
        @SerialName("deviceId")
        val deviceId: String    )

    @Serializable
    data class BlueCatbirdMlsChatUnregisterDeviceTokenOutput(
        @SerialName("success")
        val success: Boolean    )

/**
 * Remove a device push token.
 *
 * Endpoint: blue.catbird.mlsChat.unregisterDeviceToken
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.unregisterDeviceToken(
input: BlueCatbirdMlsChatUnregisterDeviceTokenInput): ATProtoResponse<BlueCatbirdMlsChatUnregisterDeviceTokenOutput> {
    val endpoint = "blue.catbird.mlsChat.unregisterDeviceToken"

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
