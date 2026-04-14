// Lexicon: 1, ID: blue.catbird.mlsChat.listDevices
// List and manage registered devices (consolidates listDevices + deleteDevice) List all registered devices for the authenticated user with key package counts and last seen timestamps. To remove a device, use the blue.catbird.mlsChat.registerDevice endpoint with the same deviceUUID (server handles cleanup), or call this endpoint with a DELETE method and deviceId parameter.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatListDevicesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.listDevices"
}

    @Serializable
    data class BlueCatbirdMlsChatListDevicesDeviceInfo(
/** Server-generated device ID (UUID) */        @SerialName("deviceId")
        val deviceId: String,/** Human-readable device name (e.g., 'Josh's iPhone') */        @SerialName("deviceName")
        val deviceName: String,/** Persistent device UUID (if provided during registration) */        @SerialName("deviceUUID")
        val deviceUUID: String? = null,/** Full device credential DID (did:plc:user#device-uuid) */        @SerialName("credentialDid")
        val credentialDid: String,/** Timestamp of last device activity */        @SerialName("lastSeenAt")
        val lastSeenAt: ATProtocolDate,/** Timestamp when device was first registered */        @SerialName("registeredAt")
        val registeredAt: ATProtocolDate,/** Number of available (unconsumed) key packages for this device */        @SerialName("keyPackageCount")
        val keyPackageCount: Int,/** Whether this device has a push token registered */        @SerialName("pushTokenRegistered")
        val pushTokenRegistered: Boolean? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatListDevicesDeviceInfo"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatListDevicesParameters(
// Optional: when provided with DELETE method, removes this device and its key packages        @SerialName("deviceId")
        val deviceId: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatListDevicesOutput(
// List of user's registered devices, ordered by last seen (most recent first)        @SerialName("devices")
        val devices: List<BlueCatbirdMlsChatListDevicesDeviceInfo>    )

/**
 * List and manage registered devices (consolidates listDevices + deleteDevice) List all registered devices for the authenticated user with key package counts and last seen timestamps. To remove a device, use the blue.catbird.mlsChat.registerDevice endpoint with the same deviceUUID (server handles cleanup), or call this endpoint with a DELETE method and deviceId parameter.
 *
 * Endpoint: blue.catbird.mlsChat.listDevices
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.listDevices(
parameters: BlueCatbirdMlsChatListDevicesParameters): ATProtoResponse<BlueCatbirdMlsChatListDevicesOutput> {
    val endpoint = "blue.catbird.mlsChat.listDevices"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
