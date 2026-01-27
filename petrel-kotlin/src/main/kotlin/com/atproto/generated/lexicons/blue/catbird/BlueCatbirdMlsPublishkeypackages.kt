// Lexicon: 1, ID: blue.catbird.mls.publishKeyPackages
// Publish multiple MLS key packages in a single batch request (up to 100 packages). More efficient than individual uploads for replenishing key package pools.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsPublishKeyPackagesDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.publishKeyPackages"
}

    /**
     * A single key package in a batch upload
     */
    @Serializable
    data class BlueCatbirdMlsPublishKeyPackagesKeyPackageItem(
/** Base64-encoded MLS key package */        @SerialName("keyPackage")
        val keyPackage: String,/** Cipher suite of the key package */        @SerialName("cipherSuite")
        val cipherSuite: String,/** Expiration timestamp (required, max 90 days from now) */        @SerialName("expires")
        val expires: ATProtocolDate,/** Client-generated UUID for deduplication within batch. Optional but recommended for reliability. */        @SerialName("idempotencyKey")
        val idempotencyKey: String?,/** Device ID for multi-device support. Used to deduplicate key packages by device when fetching. */        @SerialName("deviceId")
        val deviceId: String?,/** Device-specific credential DID (did:plc:user#device-uuid). Extracted from key package for verification. */        @SerialName("credentialDid")
        val credentialDid: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsPublishKeyPackagesKeyPackageItem"
        }
    }

    /**
     * Error information for a failed key package upload
     */
    @Serializable
    data class BlueCatbirdMlsPublishKeyPackagesBatchError(
/** Zero-based index of the key package that failed */        @SerialName("index")
        val index: Int,/** Human-readable error message describing why the upload failed */        @SerialName("error")
        val error: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#blueCatbirdMlsPublishKeyPackagesBatchError"
        }
    }

@Serializable
    data class BlueCatbirdMlsPublishKeyPackagesInput(
// Array of key packages to upload (max 100)        @SerialName("keyPackages")
        val keyPackages: List<BlueCatbirdMlsPublishKeyPackagesKeyPackageItem>    )

    @Serializable
    data class BlueCatbirdMlsPublishKeyPackagesOutput(
// Number of key packages successfully uploaded        @SerialName("succeeded")
        val succeeded: Int,// Number of key packages that failed to upload        @SerialName("failed")
        val failed: Int,// Detailed error information for failed uploads (omitted if all succeeded)        @SerialName("errors")
        val errors: List<BlueCatbirdMlsPublishKeyPackagesBatchError>? = null    )

sealed class BlueCatbirdMlsPublishKeyPackagesError(val name: String, val description: String?) {
        object BatchTooLarge: BlueCatbirdMlsPublishKeyPackagesError("BatchTooLarge", "Batch size exceeds maximum of 100 key packages")
        object InvalidBatch: BlueCatbirdMlsPublishKeyPackagesError("InvalidBatch", "Batch validation failed (see errors array in response)")
    }

/**
 * Publish multiple MLS key packages in a single batch request (up to 100 packages). More efficient than individual uploads for replenishing key package pools.
 *
 * Endpoint: blue.catbird.mls.publishKeyPackages
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.publishKeyPackages(
input: BlueCatbirdMlsPublishKeyPackagesInput): ATProtoResponse<BlueCatbirdMlsPublishKeyPackagesOutput> {
    val endpoint = "blue.catbird.mls.publishKeyPackages"

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
