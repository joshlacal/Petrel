// Lexicon: 1, ID: blue.catbird.mlsChat.getPendingDevices
// Get pending device additions for the authenticated user List pending device additions — conversations that a newly registered device should join via Welcome messages.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetPendingDevicesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getPendingDevices"
}

    @Serializable
    data class BlueCatbirdMlsChatGetPendingDevicesPendingDeviceAddition(
        @SerialName("convoId")
        val convoId: String,        @SerialName("deviceId")
        val deviceId: String,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,/** MLS Welcome message if available */        @SerialName("welcome")
        val welcome: Bytes? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatGetPendingDevicesPendingDeviceAddition"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatGetPendingDevicesParameters(
// Optional: filter to specific conversation IDs        @SerialName("convoIds")
        val convoIds: List<String>? = null,// Maximum results to return        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetPendingDevicesOutput(
        @SerialName("pendingAdditions")
        val pendingAdditions: List<BlueCatbirdMlsChatGetPendingDevicesPendingDeviceAddition>    )

/**
 * Get pending device additions for the authenticated user List pending device additions — conversations that a newly registered device should join via Welcome messages.
 *
 * Endpoint: blue.catbird.mlsChat.getPendingDevices
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getPendingDevices(
parameters: BlueCatbirdMlsChatGetPendingDevicesParameters): ATProtoResponse<BlueCatbirdMlsChatGetPendingDevicesOutput> {
    val endpoint = "blue.catbird.mlsChat.getPendingDevices"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
