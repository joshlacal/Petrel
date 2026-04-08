// Lexicon: 1, ID: blue.catbird.mlsChat.completePendingDeviceAddition
// Mark a pending device addition as complete after successful addMembers Marks a claimed pending device addition as completed. Call this after successfully adding the device via addMembers. Returns success=false with error field if pending addition not found or in wrong state.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatCompletePendingDeviceAdditionDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.completePendingDeviceAddition"
}

@Serializable
    data class BlueCatbirdMlsChatCompletePendingDeviceAdditionInput(
// ID of the pending addition to complete        @SerialName("pendingAdditionId")
        val pendingAdditionId: String,// New MLS epoch after the device was added        @SerialName("newEpoch")
        val newEpoch: Int    )

    @Serializable
    data class BlueCatbirdMlsChatCompletePendingDeviceAdditionOutput(
// Whether the completion was recorded        @SerialName("success")
        val success: Boolean,// Error code if success=false: 'PendingAdditionNotFound' or 'InvalidStatus:<status>'        @SerialName("error")
        val error: String? = null    )

sealed class BlueCatbirdMlsChatCompletePendingDeviceAdditionError(val name: String, val description: String?) {
        object NotClaimed: BlueCatbirdMlsChatCompletePendingDeviceAdditionError("NotClaimed", "Pending addition was not claimed by caller")
    }

/**
 * Mark a pending device addition as complete after successful addMembers Marks a claimed pending device addition as completed. Call this after successfully adding the device via addMembers. Returns success=false with error field if pending addition not found or in wrong state.
 *
 * Endpoint: blue.catbird.mlsChat.completePendingDeviceAddition
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.completePendingDeviceAddition(
input: BlueCatbirdMlsChatCompletePendingDeviceAdditionInput): ATProtoResponse<BlueCatbirdMlsChatCompletePendingDeviceAdditionOutput> {
    val endpoint = "blue.catbird.mlsChat.completePendingDeviceAddition"

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
