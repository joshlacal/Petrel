package com.atproto.runtime.subscription

import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.cbor.Cbor
import kotlinx.serialization.decodeFromByteArray
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import java.util.Base64
import java.util.logging.Logger

/**
 * ATProto subscription WebSocket frame helpers.
 *
 * An ATProto subscription binary frame is two concatenated CBOR items:
 *   1. Header `{ op: Int, t: String }` (`op = 1` for message, `-1` for error).
 *   2. Payload matching one of the schema union refs.
 *
 * We parse the header as a typed [CborFrameHeader] via `kotlinx-serialization-cbor`,
 * but convert the payload to a [JsonElement] tree so the existing JSON-based
 * generated (de)serialisers can decode it. Byte strings are wrapped with the
 * ATProto `{"$bytes": "base64..."}` convention to preserve binary data.
 */

private val cborLogger = Logger.getLogger("com.atproto.runtime.subscription.CborFrames")

/**
 * Header of an ATProto subscription WebSocket frame.
 *
 * `op == 1` indicates a normal message, `op == -1` indicates an error frame
 * (payload shape differs — typically `{ error: String, message: String? }`).
 * The `t` tag is the **fragment-only** NSID variant reference (e.g. `#commit`).
 */
@Serializable
data class CborFrameHeader(
    @SerialName("op") val op: Int = 0,
    @SerialName("t") val t: String = "",
)

/**
 * Parsed ATProto subscription frame, ready for variant dispatch.
 */
sealed class CborFrame {
    /** A decoded message frame. Dispatch on [header].t to pick a variant. */
    data class Message(val header: CborFrameHeader, val payload: JsonObject) : CborFrame()

    /** A server error frame (op == -1). */
    data class Error(val name: String, val message: String?) : CborFrame()
}

@Serializable
private data class CborErrorPayload(
    @SerialName("error") val error: String? = null,
    @SerialName("message") val message: String? = null,
)

/**
 * Parse a binary WebSocket frame into a [CborFrame], or `null` if the frame
 * cannot be decoded (malformed CBOR, truncated, etc.).
 *
 * Thread-safe (pure function over [data]).
 */
@OptIn(ExperimentalSerializationApi::class)
fun parseBinaryFrame(data: ByteArray): CborFrame? {
    return try {
        val headerLength = CborItemScanner.measureItem(data, 0)
        if (headerLength <= 0 || headerLength > data.size) {
            cborLogger.warning("Invalid CBOR header length: $headerLength for ${data.size} bytes")
            return null
        }

        val headerBytes = data.copyOfRange(0, headerLength)
        val header = Cbor.decodeFromByteArray<CborFrameHeader>(headerBytes)

        // op == -1 is an error frame; payload shape is { error, message }.
        if (header.op == -1) {
            val payloadBytes = data.copyOfRange(headerLength, data.size)
            val err = try {
                Cbor.decodeFromByteArray<CborErrorPayload>(payloadBytes)
            } catch (e: Exception) {
                CborErrorPayload(error = "UnknownServerError", message = e.message)
            }
            return CborFrame.Error(err.error ?: "UnknownServerError", err.message)
        }

        // op == 1 is a regular message; anything else we treat as unknown and skip.
        if (header.op != 1) return null
        if (header.t.isBlank()) return null

        val payloadBytes = data.copyOfRange(headerLength, data.size)
        val payload = decodeCborPayloadToJson(payloadBytes) ?: return null
        CborFrame.Message(header, payload)
    } catch (e: Exception) {
        cborLogger.warning("Failed to parse binary CBOR frame: ${e.message}")
        null
    }
}

/**
 * Decode CBOR payload bytes to a [JsonObject] using the ATProto `$bytes` convention.
 * Returns `null` if the payload is not a map or cannot be parsed.
 */
fun decodeCborPayloadToJson(payload: ByteArray): JsonObject? {
    return try {
        val (value, _) = CborValueParser.parse(payload, 0)
        CborValueParser.toJsonElement(value) as? JsonObject
    } catch (e: Exception) {
        cborLogger.fine("CBOR payload parse failed: ${e.message}")
        null
    }
}

// ---------------------------------------------------------------------------
// CBOR Item Length Scanner
//
// Scans CBOR major types to determine the byte length of a CBOR item. This lets
// us split the two concatenated items in an ATProto binary frame without a
// streaming decoder.
// ---------------------------------------------------------------------------

internal object CborItemScanner {

    /**
     * Measure the total byte length of a CBOR item starting at [offset].
     * Returns -1 on error (truncated, unknown major type, etc.).
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
// JsonElement. Byte strings become `{"$bytes": "base64..."}` per the ATProto
// convention used by existing generated types (e.g. `Bytes`).
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
     * Byte strings become `{"$bytes": "base64..."}` per the ATProto convention.
     */
    fun toJsonElement(value: Value): JsonElement = when (value) {
        is Value.UInt -> JsonPrimitive(value.v)
        is Value.NegInt -> JsonPrimitive(value.v)
        is Value.TextStr -> JsonPrimitive(value.v)
        is Value.Bool -> JsonPrimitive(value.v)
        is Value.Null -> JsonNull
        is Value.Float64 -> JsonPrimitive(value.v)
        is Value.ByteStr -> {
            val base64 = Base64.getEncoder().encodeToString(value.v)
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
