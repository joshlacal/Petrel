// Lexicon: 1, ID: blue.catbird.mls.getSubscriptionTicket
// Get a short-lived signed ticket for subscribing to MLS events via WebSocket. The ticket is valid for 30 seconds and must be used to establish a WebSocket connection.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdMlsGetSubscriptionTicketDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.mls.getSubscriptionTicket"
}

@Serializable
    data class BlueCatbirdMlsGetSubscriptionTicketInput(
// Optional: limit subscription to a specific conversation. If omitted, subscribes to all conversations the user is a member of.        @SerialName("convoId")
        val convoId: String? = null    )

    @Serializable
    data class BlueCatbirdMlsGetSubscriptionTicketOutput(
// Signed subscription ticket (JWT) to use as query parameter when connecting to WebSocket        @SerialName("ticket")
        val ticket: String,// WebSocket endpoint URL to connect to (e.g., wss://mls.catbird.blue/xrpc/blue.catbird.mls.subscribeConvoEvents)        @SerialName("endpoint")
        val endpoint: String,// When the ticket expires (ISO 8601). Must connect before this time.        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate    )

sealed class BlueCatbirdMlsGetSubscriptionTicketError(val name: String, val description: String?) {
        object Unauthorized: BlueCatbirdMlsGetSubscriptionTicketError("Unauthorized", "Authentication required")
        object Forbidden: BlueCatbirdMlsGetSubscriptionTicketError("Forbidden", "User is not a member of the specified conversation")
    }

/**
 * Get a short-lived signed ticket for subscribing to MLS events via WebSocket. The ticket is valid for 30 seconds and must be used to establish a WebSocket connection.
 *
 * Endpoint: blue.catbird.mls.getSubscriptionTicket
 */
suspend fun ATProtoClient.Blue.Catbird.Mls.getSubscriptionTicket(
input: BlueCatbirdMlsGetSubscriptionTicketInput): ATProtoResponse<BlueCatbirdMlsGetSubscriptionTicketOutput> {
    val endpoint = "blue.catbird.mls.getSubscriptionTicket"

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
