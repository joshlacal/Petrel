// Lexicon: 1, ID: blue.catbird.mlsChat.publishKeyPackage
// Publish an MLS key package to enable others to add you to conversations
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatPublishKeyPackageDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.publishKeyPackage"
}

@Serializable
    data class BlueCatbirdMlsChatPublishKeyPackageInput(
// Base64-encoded MLS key package        @SerialName("keyPackage")
        val keyPackage: String,// Client-generated UUID for idempotent request retries. Optional but recommended.        @SerialName("idempotencyKey")
        val idempotencyKey: String? = null,// Cipher suite of the key package        @SerialName("cipherSuite")
        val cipherSuite: String,// Expiration timestamp (required, max 90 days from now)        @SerialName("expires")
        val expires: ATProtocolDate? = null    )

    @Serializable
    class BlueCatbirdMlsChatPublishKeyPackageOutput

sealed class BlueCatbirdMlsChatPublishKeyPackageError(val name: String, val description: String?) {
        object InvalidKeyPackage: BlueCatbirdMlsChatPublishKeyPackageError("InvalidKeyPackage", "Key package is malformed or invalid")
        object InvalidCipherSuite: BlueCatbirdMlsChatPublishKeyPackageError("InvalidCipherSuite", "Cipher suite is not supported")
        object ExpirationTooFar: BlueCatbirdMlsChatPublishKeyPackageError("ExpirationTooFar", "Expiration date is too far in the future (max 90 days)")
        object TooManyKeyPackages: BlueCatbirdMlsChatPublishKeyPackageError("TooManyKeyPackages", "Maximum number of key packages per user exceeded")
    }

/**
 * Publish an MLS key package to enable others to add you to conversations
 *
 * Endpoint: blue.catbird.mlsChat.publishKeyPackage
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.publishKeyPackage(
input: BlueCatbirdMlsChatPublishKeyPackageInput): ATProtoResponse<BlueCatbirdMlsChatPublishKeyPackageOutput> {
    val endpoint = "blue.catbird.mlsChat.publishKeyPackage"

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
