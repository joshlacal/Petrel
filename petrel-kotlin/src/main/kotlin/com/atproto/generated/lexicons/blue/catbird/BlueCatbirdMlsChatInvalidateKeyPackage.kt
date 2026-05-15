// Lexicon: 1, ID: blue.catbird.mlsChat.invalidateKeyPackage
// Mark a server-stored KP as dead so the next getKeyPackages call for that DID will not select it. Underlying-KP equivalent of invalidateWelcome.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatInvalidateKeyPackageDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.invalidateKeyPackage"
}

@Serializable
    data class BlueCatbirdMlsChatInvalidateKeyPackageInput(
// DID of the device whose KP is being invalidated.        @SerialName("deviceDid")
        val deviceDid: DID,// Hex-encoded SHA-256 hash of the KP to invalidate.        @SerialName("keyPackageHash")
        val keyPackageHash: String,// Why the KP is being invalidated.        @SerialName("reason")
        val reason: String    )

    @Serializable
    data class BlueCatbirdMlsChatInvalidateKeyPackageOutput(
// True if the KP was just marked dead in this call.        @SerialName("marked")
        val marked: Boolean,// True if the KP was already dead before this call (idempotent).        @SerialName("alreadyDead")
        val alreadyDead: Boolean    )

sealed class BlueCatbirdMlsChatInvalidateKeyPackageError(val name: String, val description: String?) {
        object KeyPackageNotFound: BlueCatbirdMlsChatInvalidateKeyPackageError("KeyPackageNotFound", "No KP exists for the given (deviceDid, keyPackageHash) pair.")
        object Unauthorized: BlueCatbirdMlsChatInvalidateKeyPackageError("Unauthorized", "Caller is neither the KP owner nor a member of any convo where the failure was observed.")
    }

/**
 * Mark a server-stored KP as dead so the next getKeyPackages call for that DID will not select it. Underlying-KP equivalent of invalidateWelcome.
 *
 * Endpoint: blue.catbird.mlsChat.invalidateKeyPackage
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.invalidateKeyPackage(
input: BlueCatbirdMlsChatInvalidateKeyPackageInput): ATProtoResponse<BlueCatbirdMlsChatInvalidateKeyPackageOutput> {
    val endpoint = "blue.catbird.mlsChat.invalidateKeyPackage"

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
