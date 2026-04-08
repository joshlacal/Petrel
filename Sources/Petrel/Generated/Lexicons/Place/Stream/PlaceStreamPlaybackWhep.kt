// Lexicon: 1, ID: place.stream.playback.whep
// Play a stream over WebRTC using WHEP.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamPlaybackWhepDefs {
    const val TYPE_IDENTIFIER = "place.stream.playback.whep"
}

@Serializable
    data class PlaceStreamPlaybackWhepParameters(
// The DID of the streamer to play.        @SerialName("streamer")
        val streamer: String,// The rendition of the stream to play.        @SerialName("rendition")
        val rendition: String    )

@Serializable
    data class PlaceStreamPlaybackWhepInput(
        @SerialName("data")
        val `data`: ByteArray    )

    @Serializable
    data class PlaceStreamPlaybackWhepOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class PlaceStreamPlaybackWhepError(val name: String, val description: String?) {
        object Unauthorized: PlaceStreamPlaybackWhepError("Unauthorized", "This user may not play this stream.")
    }

/**
 * Play a stream over WebRTC using WHEP.
 *
 * Endpoint: place.stream.playback.whep
 */
suspend fun ATProtoClient.Place.Stream.Playback.whep(
input: PlaceStreamPlaybackWhepInput,
    params: PlaceStreamPlaybackWhepParameters): ATProtoResponse<PlaceStreamPlaybackWhepOutput> {
    val endpoint = "place.stream.playback.whep"

    // Blob upload - input.data is ByteArray
    val body = input.data
    val contentType = "*/*"

    val queryParams = params.toQueryParams()

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "*/*"
        ),
        body = body
    )
}
