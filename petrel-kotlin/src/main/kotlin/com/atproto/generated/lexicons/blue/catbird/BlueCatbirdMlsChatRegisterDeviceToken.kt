// Lexicon: 1, ID: blue.catbird.mlsChat.registerDeviceToken
// Register or update a device push token for APNs.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatRegisterDeviceTokenDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.registerDeviceToken"
}

@Serializable
    data class BlueCatbirdMlsChatRegisterDeviceTokenInput(
// Unique identifier for the device        @SerialName("deviceId")
        val deviceId: String,// Hex-encoded APNs device token        @SerialName("pushToken")
        val pushToken: String,// Human-readable device name        @SerialName("deviceName")
        val deviceName: String? = null,        @SerialName("platform")
        val platform: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatRegisterDeviceTokenOutput(
        @SerialName("success")
        val success: Boolean    )

/**
 * Register or update a device push token for APNs.
 *
 * Endpoint: blue.catbird.mlsChat.registerDeviceToken
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.registerDeviceToken(
input: BlueCatbirdMlsChatRegisterDeviceTokenInput): ATProtoResponse<BlueCatbirdMlsChatRegisterDeviceTokenOutput> {
    val endpoint = "blue.catbird.mlsChat.registerDeviceToken"

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
