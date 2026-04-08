// Lexicon: 1, ID: blue.catbird.mlsChat.publishKeyPackages
// Publish multiple MLS key packages in a single batch request (up to 100 packages). More efficient than individual uploads for replenishing key package pools.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatPublishKeyPackagesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.publishKeyPackages"
}

    /**
     * A single key package in a batch upload
     */
    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesKeyPackageItem(
/** Base64-encoded MLS key package */        @SerialName("keyPackage")
        val keyPackage: String,/** Cipher suite of the key package */        @SerialName("cipherSuite")
        val cipherSuite: String,/** Expiration timestamp (required, max 90 days from now) */        @SerialName("expires")
        val expires: ATProtocolDate,/** Client-generated UUID for deduplication within batch. Optional but recommended for reliability. */        @SerialName("idempotencyKey")
        val idempotencyKey: String?,/** Device ID for multi-device support. Used to deduplicate key packages by device when fetching. */        @SerialName("deviceId")
        val deviceId: String?,/** Device-specific credential DID (did:plc:user#device-uuid). Extracted from key package for verification. */        @SerialName("credentialDid")
        val credentialDid: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatPublishKeyPackagesKeyPackageItem"
        }
    }

    /**
     * Error information for a failed key package upload
     */
    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesBatchError(
/** Zero-based index of the key package that failed */        @SerialName("index")
        val index: Int,/** Human-readable error message describing why the upload failed */        @SerialName("error")
        val error: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatPublishKeyPackagesBatchError"
        }
    }

    /**
     * Key package pool statistics
     */
    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesKeyPackageStats(
/** Total number of key packages published */        @SerialName("published")
        val published: Int,/** Number of key packages currently available for consumption */        @SerialName("available")
        val available: Int,/** Number of expired key packages */        @SerialName("expired")
        val expired: Int    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsChatPublishKeyPackagesKeyPackageStats"
        }
    }

@Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesInput(
// Array of key packages to upload (max 100)        @SerialName("keyPackages")
        val keyPackages: List<BlueCatbirdMlsChatPublishKeyPackagesKeyPackageItem>    )

    @Serializable
    data class BlueCatbirdMlsChatPublishKeyPackagesOutput(
// Number of key packages successfully uploaded        @SerialName("succeeded")
        val succeeded: Int,// Number of key packages that failed to upload        @SerialName("failed")
        val failed: Int,// Detailed error information for failed uploads (omitted if all succeeded)        @SerialName("errors")
        val errors: List<BlueCatbirdMlsChatPublishKeyPackagesBatchError>? = null,// Key package pool statistics after the publish operation        @SerialName("stats")
        val stats: BlueCatbirdMlsChatPublishKeyPackagesKeyPackageStats? = null,// Result of the sync operation        @SerialName("syncResult")
        val syncResult: String? = null,// Result of the publish operation        @SerialName("publishResult")
        val publishResult: String? = null    )

sealed class BlueCatbirdMlsChatPublishKeyPackagesError(val name: String, val description: String?) {
        object BatchTooLarge: BlueCatbirdMlsChatPublishKeyPackagesError("BatchTooLarge", "Batch size exceeds maximum of 100 key packages")
        object InvalidBatch: BlueCatbirdMlsChatPublishKeyPackagesError("InvalidBatch", "Batch validation failed (see errors array in response)")
    }

/**
 * Publish multiple MLS key packages in a single batch request (up to 100 packages). More efficient than individual uploads for replenishing key package pools.
 *
 * Endpoint: blue.catbird.mlsChat.publishKeyPackages
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.publishKeyPackages(
input: BlueCatbirdMlsChatPublishKeyPackagesInput): ATProtoResponse<BlueCatbirdMlsChatPublishKeyPackagesOutput> {
    val endpoint = "blue.catbird.mlsChat.publishKeyPackages"

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
