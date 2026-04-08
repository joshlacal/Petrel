// Lexicon: 1, ID: blue.catbird.mls.registerDeviceToken
// Register or update a device push token for APNs.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsRegisterDeviceTokenDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.registerDeviceToken"
}

@Serializable
    data class BlueCatbirdMlsRegisterDeviceTokenInput(
// Unique identifier for the device        @SerialName("deviceId")
        val deviceId: String,// Hex-encoded APNs device token        @SerialName("pushToken")
        val pushToken: String,// Human-readable device name        @SerialName("deviceName")
        val deviceName: String? = null,        @SerialName("platform")
        val platform: String? = null    )

    @Serializable
    data class BlueCatbirdMlsRegisterDeviceTokenOutput(
        @SerialName("success")
        val success: Boolean    )

/**
 * Register or update a device push token for APNs.
 *
 * Endpoint: blue.catbird.mls.registerDeviceToken
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.registerDeviceToken(
input: BlueCatbirdMlsRegisterDeviceTokenInput): ATProtoResponse<BlueCatbirdMlsRegisterDeviceTokenOutput> {
    val endpoint = "blue.catbird.mls.registerDeviceToken"

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
