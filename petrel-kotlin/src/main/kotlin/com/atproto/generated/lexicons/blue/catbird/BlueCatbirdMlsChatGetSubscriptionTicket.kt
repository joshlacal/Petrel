// Lexicon: 1, ID: blue.catbird.mlsChat.getSubscriptionTicket
// Get a short-lived signed ticket for subscribing to MLS events via WebSocket. The ticket is valid for 30 seconds and must be used to establish a WebSocket connection.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsChatGetSubscriptionTicketDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mlsChat.getSubscriptionTicket"
}

@Serializable
    data class BlueCatbirdMlsChatGetSubscriptionTicketInput(
// Optional: limit subscription to specific conversations. If omitted, subscribes to all conversations the user is a member of.        @SerialName("convoIds")
        val convoIds: List<String>? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetSubscriptionTicketOutput(
// Signed subscription ticket (JWT) to use as query parameter when connecting to WebSocket        @SerialName("ticket")
        val ticket: String,// WebSocket endpoint URL to connect to (e.g., wss://mls.catbird.blue/xrpc/blue.catbird.mlsChat.subscribeConvoEvents)        @SerialName("endpoint")
        val endpoint: String,// When the ticket expires (ISO 8601). Must connect before this time.        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatGetSubscriptionTicketError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsChatGetSubscriptionTicketError("Unauthorized", "Authentication required")
        object Forbidden: BlueCatbirdMlsChatGetSubscriptionTicketError("Forbidden", "User is not a member of the specified conversation")
    }

/**
 * Get a short-lived signed ticket for subscribing to MLS events via WebSocket. The ticket is valid for 30 seconds and must be used to establish a WebSocket connection.
 *
 * Endpoint: blue.catbird.mlsChat.getSubscriptionTicket
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getSubscriptionTicket(
input: BlueCatbirdMlsChatGetSubscriptionTicketInput): ATProtoResponse<BlueCatbirdMlsChatGetSubscriptionTicketOutput> {
    val endpoint = "blue.catbird.mlsChat.getSubscriptionTicket"

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
