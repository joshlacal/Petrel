// Lexicon: 1, ID: blue.catbird.mlsChat.publishKeyPackages
// Unified key package management: publish new packages or sync with server (consolidates publishKeyPackages + syncKeyPackages + getKeyPackageStats) Manage key packages for the authenticated user's device. Supports 'publish' to upload key packages, 'sync' to compare local hashes against server, 'stats' to fetch current counts, and 'requestReplenish' to ask peer devices to replenish missing key packages.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatPublishKeyPackagesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.publishKeyPackages"
}

    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesKeyPackageItem(
/** MLS key package */        @SerialName("keyPackage")
        val keyPackage: Bytes,/** Cipher suite of the key package */        @SerialName("cipherSuite")
        val cipherSuite: String,/** Expiration timestamp (required, max 90 days from now) */        @SerialName("expires")
        val expires: ATProtocolDate    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatPublishKeyPackagesKeyPackageItem"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesKeyPackageStats(
/** Total key packages ever published for this device */        @SerialName("published")
        val published: Int,/** Currently available (unconsumed, non-expired) key packages */        @SerialName("available")
        val available: Int,/** Number of expired key packages pending cleanup */        @SerialName("expired")
        val expired: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatPublishKeyPackagesKeyPackageStats"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesSyncResult(
/** SHA256 hex hashes of available key packages on server AFTER cleanup */        @SerialName("serverHashes")
        val serverHashes: List<String>,/** Number of orphaned key packages detected */        @SerialName("orphanedCount")
        val orphanedCount: Int,/** SHA256 hex hashes of orphaned key packages that were deleted during sync */        @SerialName("orphanedHashes")
        val orphanedHashes: List<String>? = null,/** Number of orphaned key packages successfully deleted */        @SerialName("deletedCount")
        val deletedCount: Int,/** Number of valid key packages remaining after cleanup */        @SerialName("remainingAvailable")
        val remainingAvailable: Int? = null,/** Device ID that was synced (echoed back for confirmation) */        @SerialName("deviceId")
        val deviceId: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatPublishKeyPackagesSyncResult"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesPublishResult(
/** Number of key packages successfully uploaded */        @SerialName("succeeded")
        val succeeded: Int,/** Number of key packages that failed to upload */        @SerialName("failed")
        val failed: Int,/** Detailed error information for failed uploads */        @SerialName("errors")
        val errors: List<BlueCatbirdMlsChatPublishKeyPackagesBatchError>? = null    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatPublishKeyPackagesPublishResult"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesReplenishResult(
/** Whether the replenish request was accepted */        @SerialName("requested")
        val requested: Boolean,/** Number of target DIDs requested */        @SerialName("targetCount")
        val targetCount: Int,/** Number of target devices with registered push tokens */        @SerialName("deviceCount")
        val deviceCount: Int,/** Number of replenish notifications accepted by the push provider */        @SerialName("deliveredCount")
        val deliveredCount: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatPublishKeyPackagesReplenishResult"
        }
    }

    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesBatchError(
/** Zero-based index of the key package that failed */        @SerialName("index")
        val index: Int,/** Human-readable error message */        @SerialName("error")
        val error: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatPublishKeyPackagesBatchError"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesInput(
// Action to perform: 'publish' to upload new key packages, 'sync' to reconcile local/server state, 'stats' to fetch counts, or 'requestReplenish' to ask peers to refresh device keys        @SerialName("action")
        val action: String,// Key packages to upload (required for 'publish' action, max 100)        @SerialName("keyPackages")
        val keyPackages: List<BlueCatbirdMlsChatPublishKeyPackagesKeyPackageItem>? = null,// SHA256 hex hashes of key packages that exist in local storage (required for 'sync' action)        @SerialName("localHashes")
        val localHashes: List<String>? = null,// Device ID to scope the operation. Required for 'sync', recommended for 'publish'.        @SerialName("deviceId")
        val deviceId: String? = null,// Peer DIDs to notify for 'requestReplenish' action        @SerialName("targetDids")
        val targetDids: List<DID>? = null,// Optional reason included in replenish notifications        @SerialName("reason")
        val reason: String? = null,// Optional conversation context for peer replenish notifications        @SerialName("convoId")
        val convoId: String? = null    )

    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesOutput(
// Current key package statistics after the operation        @SerialName("stats")
        val stats: BlueCatbirdMlsChatPublishKeyPackagesKeyPackageStats,// Detailed sync results (only present when action is 'sync')        @SerialName("syncResult")
        val syncResult: BlueCatbirdMlsChatPublishKeyPackagesSyncResult? = null,// Detailed publish results (only present when action is 'publish')        @SerialName("publishResult")
        val publishResult: BlueCatbirdMlsChatPublishKeyPackagesPublishResult? = null,// Detailed replenish notification result (only present when action is 'requestReplenish')        @SerialName("replenishResult")
        val replenishResult: BlueCatbirdMlsChatPublishKeyPackagesReplenishResult? = null    )

sealed class BlueCatbirdMlsChatPublishKeyPackagesError(val name: String, val description: String?) {
        object InvalidAction: BlueCatbirdMlsChatPublishKeyPackagesError("InvalidAction", "Action must be 'publish', 'publishBatch', 'sync', 'stats', or 'requestReplenish'")
        object MissingKeyPackages: BlueCatbirdMlsChatPublishKeyPackagesError("MissingKeyPackages", "keyPackages required for 'publish' action")
        object MissingLocalHashes: BlueCatbirdMlsChatPublishKeyPackagesError("MissingLocalHashes", "localHashes required for 'sync' action")
        object MissingDeviceId: BlueCatbirdMlsChatPublishKeyPackagesError("MissingDeviceId", "deviceId required for 'sync' action")
        object MissingTargetDids: BlueCatbirdMlsChatPublishKeyPackagesError("MissingTargetDids", "targetDids required for 'requestReplenish' action")
        object BatchTooLarge: BlueCatbirdMlsChatPublishKeyPackagesError("BatchTooLarge", "Batch size exceeds maximum of 100 key packages")
        object InvalidBatch: BlueCatbirdMlsChatPublishKeyPackagesError("InvalidBatch", "Batch validation failed")
    }

/**
 * Unified key package management: publish new packages or sync with server (consolidates publishKeyPackages + syncKeyPackages + getKeyPackageStats) Manage key packages for the authenticated user's device. Supports 'publish' to upload key packages, 'sync' to compare local hashes against server, 'stats' to fetch current counts, and 'requestReplenish' to ask peer devices to replenish missing key packages.
 *
 * Endpoint: blue.catbird.mlsChat.publishKeyPackages
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.publishKeyPackages(
input: BlueCatbirdMlsChatPublishKeyPackagesInput): ATProtoResponse<BlueCatbirdMlsChatPublishKeyPackagesOutput> {
    val endpoint = "blue.catbird.mlsChat.publishKeyPackages"

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
