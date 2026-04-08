// Lexicon: 1, ID: blue.catbird.mlsChat.validateDeviceState
// Validate device state and sync status for the authenticated user
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatValidateDeviceStateDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.validateDeviceState"
}

    @Serializable
    data class BlueCatbirdMlsChatValidateDeviceStateKeyPackageInventory(
/** Number of available key packages */        @SerialName("available")
        val available: Int,/** Target threshold for key packages */        @SerialName("target")
        val target: Int,/** Whether more key packages need to be uploaded */        @SerialName("needsReplenishment")
        val needsReplenishment: Boolean,/** Key packages available per device */        @SerialName("perDeviceCount")
        val perDeviceCount: Int?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatValidateDeviceStateKeyPackageInventory"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatValidateDeviceStateParameters(
// Optional device ID to validate; defaults to current device        @SerialName("deviceId")
        val deviceId: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatValidateDeviceStateOutput(
// Overall validation status        @SerialName("isValid")
        val isValid: Boolean,// List of detected issues        @SerialName("issues")
        val issues: List<String>,// Actionable recommendations to fix issues        @SerialName("recommendations")
        val recommendations: List<String>,// Number of conversations device should be member of        @SerialName("expectedConvos")
        val expectedConvos: Int? = null,// Number of conversations device is actually member of        @SerialName("actualConvos")
        val actualConvos: Int? = null,        @SerialName("keyPackageInventory")
        val keyPackageInventory: BlueCatbirdMlsChatValidateDeviceStateKeyPackageInventory? = null,// List of conversation IDs with pending rejoin requests        @SerialName("pendingRejoinRequests")
        val pendingRejoinRequests: List<String>? = null    )

/**
 * Validate device state and sync status for the authenticated user
 *
 * Endpoint: blue.catbird.mlsChat.validateDeviceState
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.validateDeviceState(
parameters: BlueCatbirdMlsChatValidateDeviceStateParameters): ATProtoResponse<BlueCatbirdMlsChatValidateDeviceStateOutput> {
    val endpoint = "blue.catbird.mlsChat.validateDeviceState"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
