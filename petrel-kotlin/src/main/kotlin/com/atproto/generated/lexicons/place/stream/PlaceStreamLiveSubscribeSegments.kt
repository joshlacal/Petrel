// Lexicon: 1, ID: place.stream.live.subscribeSegments
// Subscribe to a stream's new segments as they come in!
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object PlaceStreamLiveSubscribeSegmentsDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.subscribeSegments"
}

@Serializable(with = PlaceStreamLiveSubscribeSegmentsMessageUnionSerializer::class)
sealed interface PlaceStreamLiveSubscribeSegmentsMessageUnion {
    @Serializable
    data class Unexpected(val value: JsonElement) : PlaceStreamLiveSubscribeSegmentsMessageUnion
}

object PlaceStreamLiveSubscribeSegmentsMessageUnionSerializer : kotlinx.serialization.KSerializer<PlaceStreamLiveSubscribeSegmentsMessageUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("PlaceStreamLiveSubscribeSegmentsMessageUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: PlaceStreamLiveSubscribeSegmentsMessageUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is PlaceStreamLiveSubscribeSegmentsMessageUnion.Unexpected -> value.value
            // Synthetic variants (e.g. <Union>Error / <Union>Unexpected added by
            // subscription codegen) are runtime-only sentinels; JSON round-trip
            // serialises them as an empty object tagged with the variant class
            // name. Consumers should filter these before JSON serialisation.
            else -> kotlinx.serialization.json.buildJsonObject {
                put("\$type", kotlinx.serialization.json.JsonPrimitive(value::class.simpleName ?: "Unknown"))
            }
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): PlaceStreamLiveSubscribeSegmentsMessageUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            else -> PlaceStreamLiveSubscribeSegmentsMessageUnion.Unexpected(element)
        }
    }
}

@Serializable
    data class PlaceStreamLiveSubscribeSegmentsParameters(
// The DID of the streamer to subscribe to        @SerialName("streamer")
        val streamer: String    )

    @Serializable
    class PlaceStreamLiveSubscribeSegmentsMessage

/**
 * Synthetic variants augmenting the generated PlaceStreamLiveSubscribeSegmentsMessageUnion sealed interface.
 *
 * `Error` surfaces ATProto `op == -1` server error frames; `Unexpected` wraps
 * frames whose header tag did not match any known variant (e.g. new event types
 * added server-side before client regen). Kept as extensions so the lexicon-
 * driven sealed interface stays mechanically faithful to the schema.
 */
data class PlaceStreamLiveSubscribeSegmentsMessageUnionError(val name: String, val message: String?) : PlaceStreamLiveSubscribeSegmentsMessageUnion
data class PlaceStreamLiveSubscribeSegmentsMessageUnionUnexpected(val type: String, val payload: kotlinx.serialization.json.JsonObject) : PlaceStreamLiveSubscribeSegmentsMessageUnion

/**
 * Subscribe to a stream's new segments as they come in!
 *
 * Endpoint: place.stream.live.subscribeSegments
 *
 * The returned [kotlinx.coroutines.flow.Flow] completes (or throws) when the
 * underlying WebSocket disconnects. Reconnect / cursor-resume is the caller's
 * responsibility — wrap in `retryWhen { ... }` with backoff as needed.
 */
fun ATProtoClient.Place.Stream.Live.subscribeSegments(
parameters: PlaceStreamLiveSubscribeSegmentsParameters? = null,
hostOverride: String? = null,
    websocketClient: io.ktor.client.HttpClient? = null,
): kotlinx.coroutines.flow.Flow<PlaceStreamLiveSubscribeSegmentsMessageUnion> = kotlinx.coroutines.flow.flow {
    val endpoint = "place.stream.live.subscribeSegments"
    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?collections=a&collections=b`).
    val queryItems = parameters?.toQueryItems().orEmpty()

    client.openSubscription(endpoint, queryItems, hostOverride, websocketClient) { frame ->
        val decoded: PlaceStreamLiveSubscribeSegmentsMessageUnion = when (frame) {
            is com.atproto.runtime.subscription.CborFrame.Error ->
                PlaceStreamLiveSubscribeSegmentsMessageUnionError(frame.name, frame.message)
            is com.atproto.runtime.subscription.CborFrame.Message -> {
                val json = kotlinx.serialization.json.Json {
                    ignoreUnknownKeys = true
                    isLenient = true
                }
                try {
                    when (frame.header.t) {
                        // "#segment" -> payload type `PlaceStreamLiveSubscribeSegmentsSegment` is
                        // not a @Serializable class (e.g. a top-level `type: bytes`) — surfacing
                        // it via `Unexpected` until the generator grows primitive-ref support.
                        else -> PlaceStreamLiveSubscribeSegmentsMessageUnionUnexpected(frame.header.t, frame.payload)
                    }
                } catch (e: Throwable) {
                    PlaceStreamLiveSubscribeSegmentsMessageUnionUnexpected(frame.header.t, frame.payload)
                }
            }
        }
        emit(decoded)
    }
}
