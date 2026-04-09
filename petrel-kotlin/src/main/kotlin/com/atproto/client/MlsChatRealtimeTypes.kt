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
import io.ktor.websocket.readBytes
import io.ktor.websocket.readText
import kotlinx.coroutines.flow.*
import kotlinx.serialization.*
import kotlinx.serialization.cbor.Cbor
import kotlinx.serialization.json.*
import java.util.logging.Logger

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
                    is Frame.Binary -> {
                        val data = frame.readBytes()
                        val message = parseBinaryFrame(data)
                        if (message != null) {
                            emit(message)
                        }
                    }
                    else -> { /* ignore ping/pong/close */ }
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

internal fun parseRealtimeEvent(json: JsonObject): MlsChatRealtimeEvent? {
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

// MARK: - DAG-CBOR Binary Frame Parsing
//
// AT Protocol WebSocket frames can be binary DAG-CBOR: two concatenated CBOR items
// (header + payload). The header contains {op: int, t: string} and the payload is the
// event body. This mirrors the Rust split_frame approach in catmos/src-tauri/src/websocket.rs.

private val wsLogger = Logger.getLogger("MlsChatRealtime")

/**
 * CBOR frame header from AT Protocol WebSocket binary frames.
 */
@Serializable
data class CborFrameHeader(
    val op: Int = 0,
    val t: String = ""
)

/**
 * Parse a binary DAG-CBOR WebSocket frame into a typed realtime message.
 * Returns null if the frame cannot be decoded or should be ignored.
 */
@OptIn(ExperimentalSerializationApi::class)
private fun parseBinaryFrame(data: ByteArray): MlsChatRealtimeMessage? {
    return try {
        val headerLength = CborItemScanner.measureItem(data, 0)
        if (headerLength <= 0 || headerLength >= data.size) {
            wsLogger.warning("Invalid CBOR header length: $headerLength for ${data.size} bytes")
            return null
        }

        val cbor = Cbor { ignoreUnknownKeys = true }
        val headerBytes = data.copyOfRange(0, headerLength)
        val header = cbor.decodeFromByteArray<CborFrameHeader>(headerBytes)

        // op=-1 is an error frame
        if (header.op == -1) {
            return MlsChatRealtimeMessage.Error("ServerError", "Binary error frame")
        }

        // op=1 is a regular message; ignore anything else
        if (header.op != 1) return null

        val eventType = header.t
        if (eventType.isBlank()) return null

        val payloadBytes = data.copyOfRange(headerLength, data.size)

        // Convert CBOR payload to JsonObject, then reuse existing JSON event parser
        val payloadJson = decodeCborPayloadToJson(payloadBytes)
        if (payloadJson == null) {
            wsLogger.warning("Failed to decode CBOR payload for event type: $eventType")
            return null
        }

        // Inject the event type into the payload so parseRealtimeEvent can find it
        val enrichedPayload = buildJsonObject {
            payloadJson.forEach { (key, value) -> put(key, value) }
            if (!payloadJson.containsKey("\$type") && !payloadJson.containsKey("type")) {
                // Map CBOR header event type to $type field
                // Header uses "#messageEvent" format, $type uses NSID format
                val nsidType = when {
                    eventType.startsWith("#") -> "blue.catbird.mlsChat.subscribeEvents${eventType}"
                    else -> eventType
                }
                put("\$type", JsonPrimitive(nsidType))
            }
        }

        val event = parseRealtimeEvent(enrichedPayload)
        if (event != null) {
            MlsChatRealtimeMessage.Event(seq = null, payload = event)
        } else {
            MlsChatRealtimeMessage.Unknown(eventType, seq = null)
        }
    } catch (e: Exception) {
        wsLogger.warning("Failed to parse binary CBOR frame: ${e.message}")
        MlsChatRealtimeMessage.Error("CborParseError", e.message)
    }
}

/**
 * Decode CBOR payload bytes into a [JsonObject] for the existing JSON event parsers.
 *
 * Uses a manual CBOR parser to walk the binary structure and convert to JSON.
 * Byte strings (major type 2) are converted to the AT Protocol `{"$bytes": "base64..."}`
 * format so that ciphertext and other binary data round-trip correctly through the
 * JSON-based event parsing layer.
 */
private fun decodeCborPayloadToJson(payload: ByteArray): JsonObject? {
    return try {
        val (value, _) = CborValueParser.parse(payload, 0)
        CborValueParser.toJsonElement(value) as? JsonObject
    } catch (e: Exception) {
        wsLogger.fine("CBOR payload parse failed: ${e.message}")
        null
    }
}

// ---------------------------------------------------------------------------
// CBOR Item Length Scanner
//
// Scans CBOR major types to determine byte length of a CBOR item, allowing us
// to split the two concatenated items in an AT Protocol binary frame.
// ---------------------------------------------------------------------------

internal object CborItemScanner {

    /**
     * Measure the total byte length of a CBOR item starting at [offset].
     * Returns -1 on error.
     */
    fun measureItem(data: ByteArray, offset: Int): Int {
        if (offset >= data.size) return -1

        val initial = data[offset].toInt() and 0xFF
        val majorType = initial shr 5
        val additionalInfo = initial and 0x1F
        val (argValue, headerSize) = readArgument(data, offset, additionalInfo)
        if (headerSize < 0) return -1

        return when (majorType) {
            0, 1 -> headerSize
            2, 3 -> {
                if (additionalInfo == 31) {
                    scanIndefiniteChunks(data, offset + 1)
                } else {
                    val total = headerSize + argValue.toInt()
                    if (offset + total > data.size) -1 else total
                }
            }
            4 -> {
                if (additionalInfo == 31) {
                    scanIndefiniteContainer(data, offset + 1, isMap = false)
                } else {
                    var pos = offset + headerSize
                    for (i in 0 until argValue.toInt()) {
                        val len = measureItem(data, pos)
                        if (len < 0) return -1
                        pos += len
                    }
                    pos - offset
                }
            }
            5 -> {
                if (additionalInfo == 31) {
                    scanIndefiniteContainer(data, offset + 1, isMap = true)
                } else {
                    var pos = offset + headerSize
                    for (i in 0 until argValue.toInt()) {
                        val keyLen = measureItem(data, pos)
                        if (keyLen < 0) return -1
                        pos += keyLen
                        val valLen = measureItem(data, pos)
                        if (valLen < 0) return -1
                        pos += valLen
                    }
                    pos - offset
                }
            }
            6 -> {
                val innerLen = measureItem(data, offset + headerSize)
                if (innerLen < 0) -1 else headerSize + innerLen
            }
            7 -> when (additionalInfo) {
                in 0..23 -> headerSize
                24 -> 2
                25 -> 3  // float16
                26 -> 5  // float32
                27 -> 9  // float64
                31 -> 1  // break
                else -> -1
            }
            else -> -1
        }
    }

    private fun readArgument(data: ByteArray, offset: Int, additionalInfo: Int): Pair<Long, Int> {
        return when {
            additionalInfo < 24 -> Pair(additionalInfo.toLong(), 1)
            additionalInfo == 24 -> {
                if (offset + 2 > data.size) return Pair(-1, -1)
                Pair((data[offset + 1].toInt() and 0xFF).toLong(), 2)
            }
            additionalInfo == 25 -> {
                if (offset + 3 > data.size) return Pair(-1, -1)
                val v = ((data[offset + 1].toInt() and 0xFF).toLong() shl 8) or
                    (data[offset + 2].toInt() and 0xFF).toLong()
                Pair(v, 3)
            }
            additionalInfo == 26 -> {
                if (offset + 5 > data.size) return Pair(-1, -1)
                val v = ((data[offset + 1].toInt() and 0xFF).toLong() shl 24) or
                    ((data[offset + 2].toInt() and 0xFF).toLong() shl 16) or
                    ((data[offset + 3].toInt() and 0xFF).toLong() shl 8) or
                    (data[offset + 4].toInt() and 0xFF).toLong()
                Pair(v, 5)
            }
            additionalInfo == 27 -> {
                if (offset + 9 > data.size) return Pair(-1, -1)
                var v = 0L
                for (i in 1..8) {
                    v = (v shl 8) or (data[offset + i].toInt() and 0xFF).toLong()
                }
                Pair(v, 9)
            }
            additionalInfo == 31 -> Pair(0, 1) // indefinite
            else -> Pair(-1, -1)
        }
    }

    private fun scanIndefiniteChunks(data: ByteArray, startPos: Int): Int {
        var pos = startPos
        while (pos < data.size) {
            if ((data[pos].toInt() and 0xFF) == 0xFF) {
                return (pos + 1) - (startPos - 1)
            }
            val len = measureItem(data, pos)
            if (len < 0) return -1
            pos += len
        }
        return -1
    }

    private fun scanIndefiniteContainer(data: ByteArray, startPos: Int, isMap: Boolean): Int {
        var pos = startPos
        while (pos < data.size) {
            if ((data[pos].toInt() and 0xFF) == 0xFF) {
                return (pos + 1) - (startPos - 1)
            }
            val len = measureItem(data, pos)
            if (len < 0) return -1
            pos += len
            if (isMap) {
                val valLen = measureItem(data, pos)
                if (valLen < 0) return -1
                pos += valLen
            }
        }
        return -1
    }
}

// ---------------------------------------------------------------------------
// CBOR Value Parser + JSON Converter
//
// Parses CBOR bytes into a value tree, then converts to kotlinx.serialization
// JsonElement. Handles the AT Protocol $bytes convention for byte strings.
// ---------------------------------------------------------------------------

internal object CborValueParser {

    sealed class Value {
        data class UInt(val v: Long) : Value()
        data class NegInt(val v: Long) : Value()
        data class ByteStr(val v: ByteArray) : Value()
        data class TextStr(val v: String) : Value()
        data class Arr(val items: List<Value>) : Value()
        data class MapVal(val entries: List<Pair<Value, Value>>) : Value()
        data class Bool(val v: Boolean) : Value()
        data object Null : Value()
        data class Float64(val v: Double) : Value()
        data class Tagged(val tag: Long, val inner: Value) : Value()
    }

    fun parse(data: ByteArray, offset: Int): Pair<Value, Int> {
        if (offset >= data.size) throw IllegalArgumentException("Unexpected end of CBOR at $offset")

        val initial = data[offset].toInt() and 0xFF
        val majorType = initial shr 5
        val additionalInfo = initial and 0x1F
        val (argValue, headerSize) = readArg(data, offset, additionalInfo)

        return when (majorType) {
            0 -> Pair(Value.UInt(argValue), offset + headerSize)
            1 -> Pair(Value.NegInt(-1 - argValue), offset + headerSize)
            2 -> {
                val start = offset + headerSize
                val end = start + argValue.toInt()
                Pair(Value.ByteStr(data.copyOfRange(start, end)), end)
            }
            3 -> {
                val start = offset + headerSize
                val end = start + argValue.toInt()
                Pair(Value.TextStr(String(data, start, argValue.toInt(), Charsets.UTF_8)), end)
            }
            4 -> {
                var pos = offset + headerSize
                val items = mutableListOf<Value>()
                for (i in 0 until argValue.toInt()) {
                    val (item, newPos) = parse(data, pos)
                    items.add(item)
                    pos = newPos
                }
                Pair(Value.Arr(items), pos)
            }
            5 -> {
                var pos = offset + headerSize
                val entries = mutableListOf<Pair<Value, Value>>()
                for (i in 0 until argValue.toInt()) {
                    val (key, kPos) = parse(data, pos)
                    val (value, vPos) = parse(data, kPos)
                    entries.add(Pair(key, value))
                    pos = vPos
                }
                Pair(Value.MapVal(entries), pos)
            }
            6 -> {
                val (inner, newPos) = parse(data, offset + headerSize)
                Pair(Value.Tagged(argValue, inner), newPos)
            }
            7 -> when (additionalInfo) {
                20 -> Pair(Value.Bool(false), offset + 1)
                21 -> Pair(Value.Bool(true), offset + 1)
                22 -> Pair(Value.Null, offset + 1)
                25 -> {
                    val bits = ((data[offset + 1].toInt() and 0xFF) shl 8) or
                        (data[offset + 2].toInt() and 0xFF)
                    Pair(Value.Float64(float16ToDouble(bits)), offset + 3)
                }
                26 -> {
                    val bits = ((data[offset + 1].toInt() and 0xFF) shl 24) or
                        ((data[offset + 2].toInt() and 0xFF) shl 16) or
                        ((data[offset + 3].toInt() and 0xFF) shl 8) or
                        (data[offset + 4].toInt() and 0xFF)
                    Pair(Value.Float64(Float.fromBits(bits).toDouble()), offset + 5)
                }
                27 -> {
                    var bits = 0L
                    for (i in 1..8) {
                        bits = (bits shl 8) or (data[offset + i].toInt() and 0xFF).toLong()
                    }
                    Pair(Value.Float64(Double.fromBits(bits)), offset + 9)
                }
                else -> throw IllegalArgumentException("Unknown CBOR simple value: $additionalInfo")
            }
            else -> throw IllegalArgumentException("Unknown CBOR major type: $majorType")
        }
    }

    /**
     * Convert a parsed CBOR value to a [JsonElement].
     * Byte strings become `{"$bytes": "base64..."}` per AT Protocol convention.
     */
    fun toJsonElement(value: Value): JsonElement = when (value) {
        is Value.UInt -> JsonPrimitive(value.v)
        is Value.NegInt -> JsonPrimitive(value.v)
        is Value.TextStr -> JsonPrimitive(value.v)
        is Value.Bool -> JsonPrimitive(value.v)
        is Value.Null -> JsonNull
        is Value.Float64 -> JsonPrimitive(value.v)
        is Value.ByteStr -> {
            val base64 = java.util.Base64.getEncoder().encodeToString(value.v)
            buildJsonObject { put("\$bytes", JsonPrimitive(base64)) }
        }
        is Value.Arr -> buildJsonArray { value.items.forEach { add(toJsonElement(it)) } }
        is Value.MapVal -> buildJsonObject {
            value.entries.forEach { (k, v) ->
                val keyStr = when (k) {
                    is Value.TextStr -> k.v
                    is Value.UInt -> k.v.toString()
                    is Value.NegInt -> k.v.toString()
                    else -> k.toString()
                }
                put(keyStr, toJsonElement(v))
            }
        }
        is Value.Tagged -> toJsonElement(value.inner)
    }

    private fun readArg(data: ByteArray, offset: Int, ai: Int): Pair<Long, Int> = when {
        ai < 24 -> Pair(ai.toLong(), 1)
        ai == 24 -> {
            if (offset + 2 > data.size) Pair(-1, -1)
            else Pair((data[offset + 1].toInt() and 0xFF).toLong(), 2)
        }
        ai == 25 -> {
            if (offset + 3 > data.size) Pair(-1, -1)
            else {
                val v = ((data[offset + 1].toInt() and 0xFF).toLong() shl 8) or
                    (data[offset + 2].toInt() and 0xFF).toLong()
                Pair(v, 3)
            }
        }
        ai == 26 -> {
            if (offset + 5 > data.size) Pair(-1, -1)
            else {
                val v = ((data[offset + 1].toInt() and 0xFF).toLong() shl 24) or
                    ((data[offset + 2].toInt() and 0xFF).toLong() shl 16) or
                    ((data[offset + 3].toInt() and 0xFF).toLong() shl 8) or
                    (data[offset + 4].toInt() and 0xFF).toLong()
                Pair(v, 5)
            }
        }
        ai == 27 -> {
            if (offset + 9 > data.size) Pair(-1, -1)
            else {
                var v = 0L
                for (i in 1..8) { v = (v shl 8) or (data[offset + i].toInt() and 0xFF).toLong() }
                Pair(v, 9)
            }
        }
        ai == 31 -> Pair(0, 1)
        else -> Pair(-1, -1)
    }

    private fun float16ToDouble(bits: Int): Double {
        val sign = (bits shr 15) and 1
        val exp = (bits shr 10) and 0x1F
        val mantissa = bits and 0x3FF
        return when {
            exp == 0 -> {
                val m = mantissa.toDouble() / 1024.0
                val v = m * Math.pow(2.0, -14.0)
                if (sign == 1) -v else v
            }
            exp == 31 -> {
                if (mantissa == 0) {
                    if (sign == 1) Double.NEGATIVE_INFINITY else Double.POSITIVE_INFINITY
                } else Double.NaN
            }
            else -> {
                val m = 1.0 + mantissa.toDouble() / 1024.0
                val v = m * Math.pow(2.0, (exp - 15).toDouble())
                if (sign == 1) -v else v
            }
        }
    }
}
