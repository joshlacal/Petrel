// Lexicon: 1, ID: blue.catbird.mlsChat.reissueWelcome
// Recipient device cannot decrypt the Welcome on this convo (NoMatchingKeyPackage). Server records the request and pushes a welcomeReissueRequest event to the inviter, who is expected to re-stage a new commit with a fresh KP. The recipient is told to wait. Rate limit: max 3 per (convo, recipient) per hour.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatReissueWelcomeDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.reissueWelcome"
}

@Serializable
    data class BlueCatbirdMlsChatReissueWelcomeInput(
// Conversation the failed Welcome is for.        @SerialName("convoId")
        val convoId: String,// Recipient device that cannot decrypt.        @SerialName("recipientDeviceDid")
        val recipientDeviceDid: DID,// Free-form reason for diagnostics (e.g., NoMatchingKeyPackage hex_ref=...).        @SerialName("reason")
        val reason: String    )

    @Serializable
    data class BlueCatbirdMlsChatReissueWelcomeOutput(
// True if request was recorded and inviter notified.        @SerialName("welcomeRequested")
        val welcomeRequested: Boolean,// Server timestamp.        @SerialName("requestedAt")
        val requestedAt: ATProtocolDate,// Device that will be asked to re-issue. May be empty if no admin exists.        @SerialName("inviterDevice")
        val inviterDevice: DID? = null    )

sealed class BlueCatbirdMlsChatReissueWelcomeError(val name: String, val description: String?) {
        object ConvoNotFound: BlueCatbirdMlsChatReissueWelcomeError("ConvoNotFound", "Conversation not found.")
        object NoAdminToReissue: BlueCatbirdMlsChatReissueWelcomeError("NoAdminToReissue", "No current admin/inviter exists to ask. Recipient should Surrender.")
        object RateLimited: BlueCatbirdMlsChatReissueWelcomeError("RateLimited", "Exceeded 3 requests per (convo, recipient) per hour.")
    }

/**
 * Recipient device cannot decrypt the Welcome on this convo (NoMatchingKeyPackage). Server records the request and pushes a welcomeReissueRequest event to the inviter, who is expected to re-stage a new commit with a fresh KP. The recipient is told to wait. Rate limit: max 3 per (convo, recipient) per hour.
 *
 * Endpoint: blue.catbird.mlsChat.reissueWelcome
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.reissueWelcome(
input: BlueCatbirdMlsChatReissueWelcomeInput): ATProtoResponse<BlueCatbirdMlsChatReissueWelcomeOutput> {
    val endpoint = "blue.catbird.mlsChat.reissueWelcome"

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
