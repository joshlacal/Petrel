// Lexicon: 1, ID: place.stream.live.subscribeSegments
// Subscribe to a stream's new segments as they come in!
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveSubscribeSegmentsDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.subscribeSegments"
}

@Serializable
    data class PlaceStreamLiveSubscribeSegmentsParameters(
// The DID of the streamer to subscribe to        @SerialName("streamer")
        val streamer: String    )

    @Serializable
    class PlaceStreamLiveSubscribeSegmentsMessage

/**
 * Subscribe to a stream's new segments as they come in!
 *
 * Endpoint: place.stream.live.subscribeSegments
 */
fun ATProtoClient.Place.Stream.Live.subscribeSegments(
parameters: PlaceStreamLiveSubscribeSegmentsParameters): Flow<PlaceStreamLiveSubscribeSegmentsMessage> = flow {
    val endpoint = "place.stream.live.subscribeSegments"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?collections=a&collections=b`).
    val queryItems = parameters.toQueryItems()

    // TODO: Implement WebSocket connection using a WebSocket library (e.g., Ktor WebSockets)
    // The implementation should:
    // 1. Establish WebSocket connection to endpoint with queryItems
    // 2. Listen for incoming messages
    // 3. Deserialize each message as PlaceStreamLiveSubscribeSegmentsMessage
    // 4. Emit each message to the Flow
    // Example skeleton:
    // webSocketClient.connect(endpoint, queryItems) { message ->
    //     val decoded = Json.decodeFromString<PlaceStreamLiveSubscribeSegmentsMessage>(message)
    //     emit(decoded)
    // }
    throw NotImplementedError("WebSocket subscription support requires a WebSocket client implementation")
}
