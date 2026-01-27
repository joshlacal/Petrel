// Lexicon: 1, ID: blue.catbird.mls.publishKeyPackage
// Publish an MLS key package to enable others to add you to conversations
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsPublishKeyPackageDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.publishKeyPackage"
}

@Serializable
    data class BlueCatbirdMlsPublishKeyPackageInput(
// Base64-encoded MLS key package        @SerialName("keyPackage")
        val keyPackage: String,// Client-generated UUID for idempotent request retries. Optional but recommended.        @SerialName("idempotencyKey")
        val idempotencyKey: String? = null,// Cipher suite of the key package        @SerialName("cipherSuite")
        val cipherSuite: String,// Expiration timestamp (required, max 90 days from now)        @SerialName("expires")
        val expires: ATProtocolDate? = null    )

    @Serializable
    class BlueCatbirdMlsPublishKeyPackageOutput

sealed class BlueCatbirdMlsPublishKeyPackageError(val name: String, val description: String?) {
        object InvalidKeyPackage: BlueCatbirdMlsPublishKeyPackageError("InvalidKeyPackage", "Key package is malformed or invalid")
        object InvalidCipherSuite: BlueCatbirdMlsPublishKeyPackageError("InvalidCipherSuite", "Cipher suite is not supported")
        object ExpirationTooFar: BlueCatbirdMlsPublishKeyPackageError("ExpirationTooFar", "Expiration date is too far in the future (max 90 days)")
        object TooManyKeyPackages: BlueCatbirdMlsPublishKeyPackageError("TooManyKeyPackages", "Maximum number of key packages per user exceeded")
    }

/**
 * Publish an MLS key package to enable others to add you to conversations
 *
 * Endpoint: blue.catbird.mls.publishKeyPackage
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.publishKeyPackage(
input: BlueCatbirdMlsPublishKeyPackageInput): ATProtoResponse<BlueCatbirdMlsPublishKeyPackageOutput> {
    val endpoint = "blue.catbird.mls.publishKeyPackage"

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
