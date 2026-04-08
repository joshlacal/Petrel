// Lexicon: 1, ID: blue.catbird.mlsChat.removeDevice
// Remove a registered device, its key packages, and leave all conversations the device was a member of
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatRemoveDeviceDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.removeDevice"
}

@Serializable
    data class BlueCatbirdMlsChatRemoveDeviceInput(
// Device ID to remove (must be owned by authenticated user)        @SerialName("deviceId")
        val deviceId: String    )

    @Serializable
    data class BlueCatbirdMlsChatRemoveDeviceOutput(
// True if device was successfully removed        @SerialName("deleted")
        val deleted: Boolean,// Number of key packages deleted with the device        @SerialName("keyPackagesDeleted")
        val keyPackagesDeleted: Int? = null,// Number of conversations the device was removed from        @SerialName("conversationsLeft")
        val conversationsLeft: Int? = null    )

sealed class BlueCatbirdMlsChatRemoveDeviceError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatRemoveDeviceError("Unauthorized", "User does not own this device or is not authenticated")
        object InvalidRequest: BlueCatbirdMlsChatRemoveDeviceError("InvalidRequest", "Empty or invalid device ID")
    }

/**
 * Remove a registered device, its key packages, and leave all conversations the device was a member of
 *
 * Endpoint: blue.catbird.mlsChat.removeDevice
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.removeDevice(
input: BlueCatbirdMlsChatRemoveDeviceInput): ATProtoResponse<BlueCatbirdMlsChatRemoveDeviceOutput> {
    val endpoint = "blue.catbird.mlsChat.removeDevice"

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
