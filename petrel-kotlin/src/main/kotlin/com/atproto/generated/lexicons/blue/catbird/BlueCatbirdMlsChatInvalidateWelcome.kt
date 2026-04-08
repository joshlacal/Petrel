// Lexicon: 1, ID: blue.catbird.mlsChat.invalidateWelcome
// Invalidate a Welcome message that cannot be processed (e.g., NoMatchingKeyPackage). This allows the client to fall back to External Commit or request re-addition.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatInvalidateWelcomeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.invalidateWelcome"
}

@Serializable
    data class BlueCatbirdMlsChatInvalidateWelcomeInput(
// Conversation ID        @SerialName("convoId")
        val convoId: String,// Why the Welcome cannot be processed (e.g., NoMatchingKeyPackage, KeyPackageExpired)        @SerialName("reason")
        val reason: String    )

    @Serializable
    data class BlueCatbirdMlsChatInvalidateWelcomeOutput(
// Whether a Welcome message was invalidated        @SerialName("invalidated")
        val invalidated: Boolean,// ID of the invalidated Welcome message        @SerialName("welcomeId")
        val welcomeId: String? = null    )

sealed class BlueCatbirdMlsChatInvalidateWelcomeError(val name: String, val description: String?) {
        object NotFound: BlueCatbirdMlsChatInvalidateWelcomeError("NotFound", "No unconsumed Welcome found for this conversation and user")
        object Unauthorized: BlueCatbirdMlsChatInvalidateWelcomeError("Unauthorized", "Not the recipient of this Welcome")
    }

/**
 * Invalidate a Welcome message that cannot be processed (e.g., NoMatchingKeyPackage). This allows the client to fall back to External Commit or request re-addition.
 *
 * Endpoint: blue.catbird.mlsChat.invalidateWelcome
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.invalidateWelcome(
input: BlueCatbirdMlsChatInvalidateWelcomeInput): ATProtoResponse<BlueCatbirdMlsChatInvalidateWelcomeOutput> {
    val endpoint = "blue.catbird.mlsChat.invalidateWelcome"

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
