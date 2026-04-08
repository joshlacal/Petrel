// Lexicon: 1, ID: blue.catbird.mlsChat.removeDevice
// Remove a registered MLS device and clean up associated resources (key packages, conversation memberships, pending welcome messages).
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
// The device ID to remove.        @SerialName("deviceId")
        val deviceId: String    )

    @Serializable
    data class BlueCatbirdMlsChatRemoveDeviceOutput(
// Whether the device was successfully deleted.        @SerialName("deleted")
        val deleted: Boolean,// Number of key packages that were removed.        @SerialName("keyPackagesDeleted")
        val keyPackagesDeleted: Int? = null,// Number of conversations the device was removed from.        @SerialName("conversationsLeft")
        val conversationsLeft: Int? = null    )

sealed class BlueCatbirdMlsChatRemoveDeviceError(val name: String, val description: String?) {
        object DeviceNotFound: BlueCatbirdMlsChatRemoveDeviceError("DeviceNotFound", "")
    }

/**
 * Remove a registered MLS device and clean up associated resources (key packages, conversation memberships, pending welcome messages).
 *
 * Endpoint: blue.catbird.mlsChat.removeDevice
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.removeDevice(
input: BlueCatbirdMlsChatRemoveDeviceInput): ATProtoResponse<BlueCatbirdMlsChatRemoveDeviceOutput> {
    val endpoint = "blue.catbird.mlsChat.removeDevice"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
