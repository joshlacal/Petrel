// Lexicon: 1, ID: blue.catbird.mls.deleteDevice
// Delete a registered device and all its associated key packages. Users can only delete their own devices.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsDeleteDeviceDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.deleteDevice"
}

@Serializable
    data class BlueCatbirdMlsDeleteDeviceInput(
// Device ID to delete (must be owned by authenticated user)        @SerialName("deviceId")
        val deviceId: String    )

    @Serializable
    data class BlueCatbirdMlsDeleteDeviceOutput(
// True if device was successfully deleted        @SerialName("deleted")
        val deleted: Boolean,// Number of key packages deleted with the device        @SerialName("keyPackagesDeleted")
        val keyPackagesDeleted: Int    )

sealed class BlueCatbirdMlsDeleteDeviceError(val name: String, val description: String?) {
        object DeviceNotFound: BlueCatbirdMlsDeleteDeviceError("DeviceNotFound", "The specified device does not exist")
        object Unauthorized: BlueCatbirdMlsDeleteDeviceError("Unauthorized", "User does not own this device or is not authenticated")
    }

/**
 * Delete a registered device and all its associated key packages. Users can only delete their own devices.
 *
 * Endpoint: blue.catbird.mls.deleteDevice
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.deleteDevice(
input: BlueCatbirdMlsDeleteDeviceInput): ATProtoResponse<BlueCatbirdMlsDeleteDeviceOutput> {
    val endpoint = "blue.catbird.mls.deleteDevice"

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
