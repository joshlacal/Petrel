// Lexicon: 1, ID: blue.catbird.mlsChat.deleteDevice
// Delete a registered device and all its associated key packages. Users can only delete their own devices.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatDeleteDeviceDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.deleteDevice"
}

@Serializable
    data class BlueCatbirdMlsChatDeleteDeviceInput(
// Device ID to delete (must be owned by authenticated user)        @SerialName("deviceId")
        val deviceId: String    )

    @Serializable
    data class BlueCatbirdMlsChatDeleteDeviceOutput(
// True if device was successfully deleted        @SerialName("deleted")
        val deleted: Boolean,// Number of key packages deleted with the device        @SerialName("keyPackagesDeleted")
        val keyPackagesDeleted: Int    )

sealed class BlueCatbirdMlsChatDeleteDeviceError(val name: String, val description: String?) {
        object DeviceNotFound: BlueCatbirdMlsChatDeleteDeviceError("DeviceNotFound", "The specified device does not exist")
        object Unauthorized: BlueCatbirdMlsChatDeleteDeviceError("Unauthorized", "User does not own this device or is not authenticated")
    }

/**
 * Delete a registered device and all its associated key packages. Users can only delete their own devices.
 *
 * Endpoint: blue.catbird.mlsChat.deleteDevice
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.deleteDevice(
input: BlueCatbirdMlsChatDeleteDeviceInput): ATProtoResponse<BlueCatbirdMlsChatDeleteDeviceOutput> {
    val endpoint = "blue.catbird.mlsChat.deleteDevice"

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
