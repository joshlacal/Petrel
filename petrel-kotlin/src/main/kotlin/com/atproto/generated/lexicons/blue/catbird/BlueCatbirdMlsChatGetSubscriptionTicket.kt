// Lexicon: 1, ID: blue.catbird.mlsChat.getSubscriptionTicket
// Get a short-lived ticket for WebSocket subscription authentication (same as v1, in v2 namespace) Get a short-lived ticket for WebSocket subscription authentication. Call this via PDS proxy, then connect directly to the MLS DS WebSocket endpoint with the ticket.
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
// Conversation IDs to subscribe to. If omitted, subscribes to all user conversations.        @SerialName("convoIds")
        val convoIds: List<String>? = null    )

    @Serializable
    data class BlueCatbirdMlsChatGetSubscriptionTicketOutput(
// Short-lived JWT ticket for WebSocket authentication        @SerialName("ticket")
        val ticket: String,// WebSocket endpoint URL to connect to        @SerialName("endpoint")
        val endpoint: URI? = null,// Ticket expiration time (typically 30 seconds from issuance)        @SerialName("expiresAt")
        val expiresAt: ATProtocolDate    )

sealed class BlueCatbirdMlsChatGetSubscriptionTicketError(val name: String, val description: String?) {
        object NotMember: BlueCatbirdMlsChatGetSubscriptionTicketError("NotMember", "User is not a member of one or more specified conversations")
    }

/**
 * Get a short-lived ticket for WebSocket subscription authentication (same as v1, in v2 namespace) Get a short-lived ticket for WebSocket subscription authentication. Call this via PDS proxy, then connect directly to the MLS DS WebSocket endpoint with the ticket.
 *
 * Endpoint: blue.catbird.mlsChat.getSubscriptionTicket
 */
suspend fun ATProtoClient.Blue.Catbird.MlsChat.getSubscriptionTicket(
input: BlueCatbirdMlsChatGetSubscriptionTicketInput): ATProtoResponse<BlueCatbirdMlsChatGetSubscriptionTicketOutput> {
    val endpoint = "blue.catbird.mlsChat.getSubscriptionTicket"

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
