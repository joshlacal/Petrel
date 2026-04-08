// Lexicon: 1, ID: blue.catbird.mls.completePendingDeviceAddition
// Mark a pending device addition as complete after successful addMembers Marks a claimed pending device addition as completed. Call this after successfully adding the device via addMembers. Returns success=false with error field if pending addition not found or in wrong state.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsCompletePendingDeviceAdditionDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.completePendingDeviceAddition"
}

@Serializable
    data class BlueCatbirdMlsCompletePendingDeviceAdditionInput(
// ID of the pending addition to complete        @SerialName("pendingAdditionId")
        val pendingAdditionId: String,// New MLS epoch after the device was added        @SerialName("newEpoch")
        val newEpoch: Int    )

    @Serializable
    data class BlueCatbirdMlsCompletePendingDeviceAdditionOutput(
// Whether the completion was recorded        @SerialName("success")
        val success: Boolean,// Error code if success=false: 'PendingAdditionNotFound' or 'InvalidStatus:<status>'        @SerialName("error")
        val error: String? = null    )

sealed class BlueCatbirdMlsCompletePendingDeviceAdditionError(val name: String, val description: String?) {
        object NotClaimed: BlueCatbirdMlsCompletePendingDeviceAdditionError("NotClaimed", "Pending addition was not claimed by caller")
    }

/**
 * Mark a pending device addition as complete after successful addMembers Marks a claimed pending device addition as completed. Call this after successfully adding the device via addMembers. Returns success=false with error field if pending addition not found or in wrong state.
 *
 * Endpoint: blue.catbird.mls.completePendingDeviceAddition
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.completePendingDeviceAddition(
input: BlueCatbirdMlsCompletePendingDeviceAdditionInput): ATProtoResponse<BlueCatbirdMlsCompletePendingDeviceAdditionOutput> {
    val endpoint = "blue.catbird.mls.completePendingDeviceAddition"

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
