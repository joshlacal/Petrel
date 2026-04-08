// Lexicon: 1, ID: blue.catbird.mls.syncKeyPackages
// Synchronize key packages between client and server to prevent NoMatchingKeyPackage errors. Compares server-side available key packages against client-provided local hashes and deletes orphaned server packages that no longer have corresponding private keys on the device. MULTI-DEVICE: deviceId is REQUIRED - only syncs packages for that specific device to prevent cross-device interference.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsSyncKeyPackagesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.syncKeyPackages"
}

@Serializable
    data class BlueCatbirdMlsSyncKeyPackagesInput(
// SHA256 hex hashes of key packages that exist in local storage (have private keys)        @SerialName("localHashes")
        val localHashes: List<String>,// Device ID to scope the sync (REQUIRED). Only syncs key packages belonging to this device. This is the deviceId returned from registerDevice.        @SerialName("deviceId")
        val deviceId: String    )

    @Serializable
    data class BlueCatbirdMlsSyncKeyPackagesOutput(
// SHA256 hex hashes of available (unconsumed) key packages on server AFTER cleanup        @SerialName("serverHashes")
        val serverHashes: List<String>,// Number of orphaned key packages detected (on server but not in local storage)        @SerialName("orphanedCount")
        val orphanedCount: Int,// Number of orphaned key packages successfully deleted        @SerialName("deletedCount")
        val deletedCount: Int,// Hashes of orphaned packages that were deleted (for debugging)        @SerialName("orphanedHashes")
        val orphanedHashes: List<String>? = null,// Number of valid key packages remaining after cleanup        @SerialName("remainingAvailable")
        val remainingAvailable: Int? = null,// Device ID that was synced (echoed back for confirmation)        @SerialName("deviceId")
        val deviceId: String    )

/**
 * Synchronize key packages between client and server to prevent NoMatchingKeyPackage errors. Compares server-side available key packages against client-provided local hashes and deletes orphaned server packages that no longer have corresponding private keys on the device. MULTI-DEVICE: deviceId is REQUIRED - only syncs packages for that specific device to prevent cross-device interference.
 *
 * Endpoint: blue.catbird.mls.syncKeyPackages
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.syncKeyPackages(
input: BlueCatbirdMlsSyncKeyPackagesInput): ATProtoResponse<BlueCatbirdMlsSyncKeyPackagesOutput> {
    val endpoint = "blue.catbird.mls.syncKeyPackages"

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
