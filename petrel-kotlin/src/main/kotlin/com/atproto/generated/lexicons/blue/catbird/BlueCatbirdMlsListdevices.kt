// Lexicon: 1, ID: blue.catbird.mls.listDevices
// List all registered devices for the authenticated user with key package counts and last seen timestamps
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsListDevicesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.listDevices"
}

    @Serializable
    data class BlueCatbirdMlsListDevicesDeviceInfo(
/** Server-generated device ID (UUID) */        @SerialName("deviceId")
        val deviceId: String,/** Human-readable device name (e.g., 'Josh's iPhone') */        @SerialName("deviceName")
        val deviceName: String,/** Persistent device UUID (if provided during registration) */        @SerialName("deviceUUID")
        val deviceUUID: String?,/** Full device credential DID (did:plc:user#device-uuid) */        @SerialName("credentialDid")
        val credentialDid: String,/** Timestamp of last device activity */        @SerialName("lastSeenAt")
        val lastSeenAt: ATProtocolDate,/** Timestamp when device was first registered */        @SerialName("registeredAt")
        val registeredAt: ATProtocolDate,/** Number of available (unconsumed) key packages for this device */        @SerialName("keyPackageCount")
        val keyPackageCount: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsListDevicesDeviceInfo"
        }
    }

@Serializable
    class BlueCatbirdMlsListDevicesParameters

    @Serializable
    data class BlueCatbirdMlsListDevicesOutput(
// List of user's registered devices, ordered by last seen (most recent first)        @SerialName("devices")
        val devices: List<BlueCatbirdMlsListDevicesDeviceInfo>    )

/**
 * List all registered devices for the authenticated user with key package counts and last seen timestamps
 *
 * Endpoint: blue.catbird.mls.listDevices
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.listDevices(
parameters: BlueCatbirdMlsListDevicesParameters): ATProtoResponse<BlueCatbirdMlsListDevicesOutput> {
    val endpoint = "blue.catbird.mls.listDevices"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
