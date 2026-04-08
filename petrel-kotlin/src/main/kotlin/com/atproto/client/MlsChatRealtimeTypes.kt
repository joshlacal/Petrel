package com.atproto.client

import com.atproto.core.types.*
import com.atproto.generated.*
import com.atproto.network.ATProtoResponse
import io.ktor.client.HttpClient
import io.ktor.client.engine.cio.CIO
import io.ktor.client.plugins.websocket.WebSockets
import io.ktor.client.plugins.websocket.webSocket
import io.ktor.client.plugins.websocket.DefaultClientWebSocketSession
import io.ktor.websocket.Frame
import io.ktor.websocket.readText
import kotlinx.coroutines.flow.*
import kotlinx.serialization.*
import kotlinx.serialization.json.*

// MARK: - MLS Chat Realtime Event Types
//
// Hand-written bridge types used by the Android app for real-time MLS event streaming.
// These provide simplified interfaces over the generated BlueCatbirdMlsChatSubscribeEvents* types.

/**
 * Sealed interface for all MLS chat realtime events.
 */
sealed interface MlsChatRealtimeEvent

/**
 * Sealed class representing a framed realtime message from the WebSocket.
 */
sealed class MlsChatRealtimeMessage {
    data class Event(val seq: Long?, val payload: MlsChatRealtimeEvent) : MlsChatRealtimeMessage()
    data class Error(val error: String, val message: String?) : MlsChatRealtimeMessage()
    data class Unknown(val type: String, val seq: Long?) : MlsChatRealtimeMessage()
}

/**
 * A new message was received in a conversation.
 */
data class MlsChatMessageEvent(
    val cursor: String,
    val message: BlueCatbirdMlsChatDefsMessageView,
    val ephemeral: Boolean? = null
) : MlsChatRealtimeEvent

/**
 * A reaction was added or removed on a message.
 */
data class MlsChatReactionEvent(
    val cursor: String,
    val convoId: String,
    val messageId: String,
    val did: DID,
    val emoji: String,
    val reaction: String,
    val action: String
) : MlsChatRealtimeEvent

/**
 * A user started or stopped typing.
 */
data class MlsChatTypingEvent(
    val cursor: String,
    val convoId: String,
    val did: DID,
    val isTyping: Boolean
) : MlsChatRealtimeEvent

/**
 * An informational event (heartbeat, system notice, or synthesized from other events).
 */
data class MlsChatInfoEvent(
    val cursor: String,
    val info: String,
    val convoId: String? = null,
    val infoType: String? = null,
    val requestedBy: String? = null
) : MlsChatRealtimeEvent

/**
 * A user has read messages in a conversation.
 */
data class MlsChatReadEvent(
    val cursor: String,
    val convoId: String,
    val did: DID,
    val messageId: String? = null
) : MlsChatRealtimeEvent

/**
 * A new device was registered and needs to be added to conversations.
 */
data class MlsChatNewDeviceEvent(
    val cursor: String,
    val convoId: String,
    val userDid: String,
    val deviceId: String,
    val deviceName: String? = null
) : MlsChatRealtimeEvent

/**
 * A member joined, left, or was removed from a conversation.
 */
data class MlsChatMembershipChangeEvent(
    val cursor: String,
    val convoId: String,
    val did: String,
    val action: String
) : MlsChatRealtimeEvent

/**
 * An active member should publish fresh GroupInfo for external commit joins.
 */
data class MlsChatGroupInfoRefreshRequestedEvent(
    val cursor: String,
    val convoId: String
) : MlsChatRealtimeEvent

/**
 * A member needs to be re-added to the conversation.
 */
data class MlsChatReadditionRequestedEvent(
    val cursor: String,
    val convoId: String,
    val userDid: String
) : MlsChatRealtimeEvent

/**
 * A group has been reset by the server (epoch spiral recovery).
 * Clients should set resetPending=true and prepare for External Commit rejoin.
 */
data class MlsChatGroupResetEvent(
    val cursor: String,
    val convoId: String,
    val newGroupId: String? = null,
    val reason: String? = null
) : MlsChatRealtimeEvent

// MARK: - subscribeEvents extension function
//
// Convenience extension on ATProtoClient.Blue.Catbird.MlsChat that provides
// individual parameters instead of a Parameters object, and returns typed
// MlsChatRealtimeMessage instead of the raw generated message type.

/**
 * Subscribe to live MLS conversation events via WebSocket.
 *
 * @param convoIds Optional list of conversation IDs to filter events. Null for all.
 * @param cursor Optional resume cursor from a previous session.
 * @param websocketClient Optional HttpClient with WebSocket engine (CIO). If null, a default is created.
 * @return Flow of typed [MlsChatRealtimeMessage] events.
 */
fun ATProtoClient.Blue.Catbird.MlsChat.subscribeEvents(
    convoIds: List<String>? = null,
    cursor: String? = null,
    websocketClient: HttpClient? = null
): Flow<MlsChatRealtimeMessage> = flow {
    // Get subscription ticket first
    val ticketInput = BlueCatbirdMlsChatGetSubscriptionTicketInput(convoIds = convoIds)
    val ticketResponse = client.blue.catbird.mlschat.getSubscriptionTicket(ticketInput)
    val output = ticketResponse.data
        ?: throw IllegalStateException("Failed to get subscription ticket (HTTP ${ticketResponse.responseCode})")
    val ticket = output.ticket
    val endpoint = output.endpoint

    // Use endpoint from ticket response, falling back to constructed URL
    val wsUrl = buildString {
        val base = if (endpoint?.toString()?.isNotBlank() == true) {
            endpoint.toString()
        } else {
            val baseUrl = client.networkService.getBaseUrl()
                .replace("https://", "wss://")
                .replace("http://", "ws://")
            "$baseUrl/xrpc/blue.catbird.mlsChat.subscribeEvents"
        }
        append(base)
        append(if ('?' in base) "&" else "?")
        append("ticket=$ticket")
        if (cursor != null) append("&cursor=$cursor")
        convoIds?.forEach { id -> append("&convoIds=$id") }
    }

    val wsClient = websocketClient ?: createDefaultWebSocketClient()

    try {
        wsClient.webSocket(wsUrl) {
            for (frame in incoming) {
                when (frame) {
                    is Frame.Text -> {
                        val text = frame.readText()
                        val message = parseRealtimeMessage(text)
                        emit(message)
                    }
                    else -> { /* ignore non-text frames */ }
                }
            }
        }
    } finally {
        if (websocketClient == null) {
            wsClient.close()
        }
    }
}

private fun createDefaultWebSocketClient(): HttpClient {
    return HttpClient(CIO) {
        install(WebSockets) {
            pingIntervalMillis = 30_000
        }
    }
}

private val realtimeJson = Json {
    ignoreUnknownKeys = true
    isLenient = true
}

internal fun parseRealtimeMessage(text: String): MlsChatRealtimeMessage {
    return try {
        val json = realtimeJson.parseToJsonElement(text).jsonObject
        val type = json["t"]?.jsonPrimitive?.contentOrNull
            ?: json["type"]?.jsonPrimitive?.contentOrNull

        when (type) {
            "event", null -> {
                val seq = json["seq"]?.jsonPrimitive?.longOrNull
                val payload = parseRealtimeEvent(json)
                if (payload != null) {
                    MlsChatRealtimeMessage.Event(seq, payload)
                } else {
                    MlsChatRealtimeMessage.Unknown(type ?: "event", seq)
                }
            }
            "error" -> {
                val error = json["error"]?.jsonPrimitive?.contentOrNull ?: "Unknown"
                val message = json["message"]?.jsonPrimitive?.contentOrNull
                MlsChatRealtimeMessage.Error(error, message)
            }
            else -> {
                val seq = json["seq"]?.jsonPrimitive?.longOrNull
                MlsChatRealtimeMessage.Unknown(type, seq)
            }
        }
    } catch (e: Exception) {
        MlsChatRealtimeMessage.Error("ParseError", e.message)
    }
}

private fun parseRealtimeEvent(json: JsonObject): MlsChatRealtimeEvent? {
    // The event type can be in "$type", "type", or "t" field within the payload
    val payload = json["payload"]?.jsonObject ?: json
    val eventType = payload["\$type"]?.jsonPrimitive?.contentOrNull
        ?: payload["type"]?.jsonPrimitive?.contentOrNull
        ?: return null

    return try {
        when {
            eventType.contains("messageEvent", ignoreCase = true) ||
            eventType.contains("#message") -> {
                val messageJson = payload["message"]?.jsonObject ?: return null
                val message = realtimeJson.decodeFromJsonElement<BlueCatbirdMlsChatDefsMessageView>(messageJson)
                val cursor = payload["cursor"]?.jsonPrimitive?.contentOrNull ?: ""
                val ephemeral = payload["ephemeral"]?.jsonPrimitive?.booleanOrNull
                MlsChatMessageEvent(cursor = cursor, message = message, ephemeral = ephemeral)
            }
            eventType.contains("reactionEvent", ignoreCase = true) ||
            eventType.contains("#reaction") -> {
                realtimeJson.decodeFromJsonElement<MlsChatReactionEvent>(payload)
            }
            eventType.contains("typingEvent", ignoreCase = true) ||
            eventType.contains("#typing") -> {
                realtimeJson.decodeFromJsonElement<MlsChatTypingEvent>(payload)
            }
            eventType.contains("infoEvent", ignoreCase = true) ||
            eventType.contains("#info") -> {
                realtimeJson.decodeFromJsonElement<MlsChatInfoEvent>(payload)
            }
            eventType.contains("readEvent", ignoreCase = true) ||
            eventType.contains("#read") -> {
                realtimeJson.decodeFromJsonElement<MlsChatReadEvent>(payload)
            }
            eventType.contains("newDeviceEvent", ignoreCase = true) ||
            eventType.contains("#newDevice") -> {
                realtimeJson.decodeFromJsonElement<MlsChatNewDeviceEvent>(payload)
            }
            eventType.contains("membershipChangeEvent", ignoreCase = true) ||
            eventType.contains("#membershipChange") -> {
                realtimeJson.decodeFromJsonElement<MlsChatMembershipChangeEvent>(payload)
            }
            eventType.contains("groupInfoRefreshRequested", ignoreCase = true) ||
            eventType.contains("#groupInfoRefresh") -> {
                realtimeJson.decodeFromJsonElement<MlsChatGroupInfoRefreshRequestedEvent>(payload)
            }
            eventType.contains("readditionRequested", ignoreCase = true) ||
            eventType.contains("#readdition") -> {
                realtimeJson.decodeFromJsonElement<MlsChatReadditionRequestedEvent>(payload)
            }
            eventType.contains("groupResetEvent", ignoreCase = true) ||
            eventType.contains("#groupReset") -> {
                realtimeJson.decodeFromJsonElement<MlsChatGroupResetEvent>(payload)
            }
            else -> null
        }
    } catch (e: Exception) {
        null
    }
}
