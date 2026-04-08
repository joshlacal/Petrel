// Lexicon: 1, ID: blue.catbird.mls.invalidateWelcome
// Invalidate a Welcome message that cannot be processed (e.g., NoMatchingKeyPackage). This allows the client to fall back to External Commit or request re-addition.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsInvalidateWelcomeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.invalidateWelcome"
}

@Serializable
    data class BlueCatbirdMlsInvalidateWelcomeInput(
// Conversation ID        @SerialName("convoId")
        val convoId: String,// Why the Welcome cannot be processed (e.g., NoMatchingKeyPackage, KeyPackageExpired)        @SerialName("reason")
        val reason: String    )

    @Serializable
    data class BlueCatbirdMlsInvalidateWelcomeOutput(
// Whether a Welcome message was invalidated        @SerialName("invalidated")
        val invalidated: Boolean,// ID of the invalidated Welcome message        @SerialName("welcomeId")
        val welcomeId: String? = null    )

sealed class BlueCatbirdMlsInvalidateWelcomeError(val name: String, val description: String?) {
        object NotFound: BlueCatbirdMlsInvalidateWelcomeError("NotFound", "No unconsumed Welcome found for this conversation and user")
        object Unauthorized: BlueCatbirdMlsInvalidateWelcomeError("Unauthorized", "Not the recipient of this Welcome")
    }

/**
 * Invalidate a Welcome message that cannot be processed (e.g., NoMatchingKeyPackage). This allows the client to fall back to External Commit or request re-addition.
 *
 * Endpoint: blue.catbird.mls.invalidateWelcome
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.invalidateWelcome(
input: BlueCatbirdMlsInvalidateWelcomeInput): ATProtoResponse<BlueCatbirdMlsInvalidateWelcomeOutput> {
    val endpoint = "blue.catbird.mls.invalidateWelcome"

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
