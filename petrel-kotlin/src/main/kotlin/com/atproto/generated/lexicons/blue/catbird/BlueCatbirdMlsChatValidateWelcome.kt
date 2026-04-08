// Lexicon: 1, ID: blue.catbird.mlsChat.validateWelcome
// Validate a Welcome message before processing and reserve the referenced key package. Prevents race conditions and helps clients detect missing bundles early.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatValidateWelcomeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.validateWelcome"
}

@Serializable
    data class BlueCatbirdMlsChatValidateWelcomeInput(
// MLS Welcome message bytes to validate        @SerialName("welcomeMessage")
        val welcomeMessage: ByteArray    )

    @Serializable
    data class BlueCatbirdMlsChatValidateWelcomeOutput(
// Whether the Welcome message is valid and key package is available        @SerialName("valid")
        val valid: Boolean,// SHA256 hex hash of the key package referenced in the Welcome message        @SerialName("keyPackageHash")
        val keyPackageHash: String,// DID of the recipient (authenticated user). Confirms Welcome is for this user.        @SerialName("recipientDid")
        val recipientDid: DID? = null,// MLS group identifier (hex-encoded) extracted from Welcome message        @SerialName("groupId")
        val groupId: String? = null,// Whether the key package was successfully reserved. If true, client should process Welcome within 5 minutes.        @SerialName("reserved")
        val reserved: Boolean? = null,// Timestamp when reservation expires (5 minutes from now). Only present if reserved is true.        @SerialName("reservedUntil")
        val reservedUntil: ATProtocolDate? = null    )

sealed class BlueCatbirdMlsChatValidateWelcomeError(val name: String, val description: String?) {
        object InvalidWelcome: BlueCatbirdMlsChatValidateWelcomeError("InvalidWelcome", "Welcome message is malformed or cannot be parsed")
        object KeyPackageNotFound: BlueCatbirdMlsChatValidateWelcomeError("KeyPackageNotFound", "Referenced key package was never uploaded by this user")
        object KeyPackageAlreadyConsumed: BlueCatbirdMlsChatValidateWelcomeError("KeyPackageAlreadyConsumed", "Referenced key package has already been used")
        object KeyPackageReserved: BlueCatbirdMlsChatValidateWelcomeError("KeyPackageReserved", "Referenced key package is reserved by another Welcome message")
        object RecipientMismatch: BlueCatbirdMlsChatValidateWelcomeError("RecipientMismatch", "Welcome message is not for the authenticated user")
    }

/**
 * Validate a Welcome message before processing and reserve the referenced key package. Prevents race conditions and helps clients detect missing bundles early.
 *
 * Endpoint: blue.catbird.mlsChat.validateWelcome
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.validateWelcome(
input: BlueCatbirdMlsChatValidateWelcomeInput): ATProtoResponse<BlueCatbirdMlsChatValidateWelcomeOutput> {
    val endpoint = "blue.catbird.mlsChat.validateWelcome"

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
