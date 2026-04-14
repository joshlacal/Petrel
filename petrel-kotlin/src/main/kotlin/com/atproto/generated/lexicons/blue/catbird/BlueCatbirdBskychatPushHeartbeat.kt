// Lexicon: 1, ID: blue.catbird.bskychat.pushHeartbeat
// Send a heartbeat to indicate the client is actively viewing chat. Suppresses server-side polling.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object BlueCatbirdBskychatPushHeartbeatDefs {
    const val TYPE_IDENTIFIER = "blue.catbird.bskychat.pushHeartbeat"
}

@Serializable
    data class BlueCatbirdBskychatPushHeartbeatInput(
// Client platform identifier (e.g., 'ios', 'macos')        @SerialName("platform")
        val platform: String    )

    @Serializable
    data class BlueCatbirdBskychatPushHeartbeatOutput(
// When the foreground lease expires        @SerialName("leaseExpiresAt")
        val leaseExpiresAt: ATProtocolDate    )

/**
 * Send a heartbeat to indicate the client is actively viewing chat. Suppresses server-side polling.
 *
 * Endpoint: blue.catbird.bskychat.pushHeartbeat
 */
suspend fun ATProtoClient.Blue.Catbird.Bskychat.pushHeartbeat(
input: BlueCatbirdBskychatPushHeartbeatInput): ATProtoResponse<BlueCatbirdBskychatPushHeartbeatOutput> {
    val endpoint = "blue.catbird.bskychat.pushHeartbeat"

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
