// Lexicon: 1, ID: blue.catbird.mlsChat.reconcileKeyPackages
// Bidirectional KP diff between client local store and server. Replaces publishKeyPackages action=sync for full reconciliation. Server returns BOTH directions of the diff (serverOnly + localOnly) and does NOT auto-delete on either side.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatReconcileKeyPackagesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.reconcileKeyPackages"
}

@Serializable
    data class BlueCatbirdMlsChatReconcileKeyPackagesInput(
// Calling device identifier.        @SerialName("deviceId")
        val deviceId: String,// Hex-encoded SHA-256 hashes of every KP the client claims to have locally.        @SerialName("localHashes")
        val localHashes: List<String>,// Reconciliation protocol version. Always 2 for this endpoint.        @SerialName("schemaVersion")
        val schemaVersion: Int    )

    @Serializable
    data class BlueCatbirdMlsChatReconcileKeyPackagesOutput(
// Hashes server has but client did not claim. Client SHOULD delete from local manifest if it can't find them, OR notify user that account has stale key material from a previous install.        @SerialName("serverOnly")
        val serverOnly: List<String>,// Hashes client claims but server doesn't have. Client SHOULD re-publish via publishKeyPackages. Server will NOT auto-delete these.        @SerialName("localOnly")
        val localOnly: List<String>,// Total KP count on server for this device after the call (excluding dead KPs).        @SerialName("total")
        val total: Int,// True iff local_hashes ⊆ server_hashes AND server_hashes ⊆ local_hashes ∪ {expired for this device}. Verified status is the green-light signal for inviters to use this device's KPs.        @SerialName("deviceVerified")
        val deviceVerified: Boolean    )

sealed class BlueCatbirdMlsChatReconcileKeyPackagesError(val name: String, val description: String?) {
        object DeviceNotFound: BlueCatbirdMlsChatReconcileKeyPackagesError("DeviceNotFound", "deviceId is not registered.")
        object Unauthorized: BlueCatbirdMlsChatReconcileKeyPackagesError("Unauthorized", "Caller is not the owner of deviceId.")
    }

/**
 * Bidirectional KP diff between client local store and server. Replaces publishKeyPackages action=sync for full reconciliation. Server returns BOTH directions of the diff (serverOnly + localOnly) and does NOT auto-delete on either side.
 *
 * Endpoint: blue.catbird.mlsChat.reconcileKeyPackages
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.reconcileKeyPackages(
input: BlueCatbirdMlsChatReconcileKeyPackagesInput): ATProtoResponse<BlueCatbirdMlsChatReconcileKeyPackagesOutput> {
    val endpoint = "blue.catbird.mlsChat.reconcileKeyPackages"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
