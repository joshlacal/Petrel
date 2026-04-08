// Lexicon: 1, ID: place.stream.playback.getPlaybackServer
// Get available playback servers for a livestream.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamPlaybackGetPlaybackServerDefs {
    const val TYPE_IDENTIFIER = "place.stream.playback.getPlaybackServer"
}

@Serializable
    data class PlaceStreamPlaybackGetPlaybackServerParameters(
// Identifier of the stream to get playback servers for        @SerialName("stream")
        val stream: String    )

    @Serializable
    data class PlaceStreamPlaybackGetPlaybackServerOutput(
// List of available playback server addresses        @SerialName("servers")
        val servers: List<String>    )

/**
 * Get available playback servers for a livestream.
 *
 * Endpoint: place.stream.playback.getPlaybackServer
 */
suspend fun ATProtoClient.Place.Stream.Playback.getPlaybackServer(
parameters: PlaceStreamPlaybackGetPlaybackServerParameters): ATProtoResponse<PlaceStreamPlaybackGetPlaybackServerOutput> {
    val endpoint = "place.stream.playback.getPlaybackServer"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
