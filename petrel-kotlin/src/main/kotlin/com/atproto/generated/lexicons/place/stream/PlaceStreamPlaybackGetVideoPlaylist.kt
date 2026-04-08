// Lexicon: 1, ID: place.stream.playback.getVideoPlaylist
// Get the HLS playlist for a video
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamPlaybackGetVideoPlaylistDefs {
    const val TYPE_IDENTIFIER = "place.stream.playback.getVideoPlaylist"
}

@Serializable
    data class PlaceStreamPlaybackGetVideoPlaylistParameters(
// The AT URI of the video record        @SerialName("uri")
        val uri: ATProtocolURI,// Track number to retrieve        @SerialName("track")
        val track: Int? = null    )

    @Serializable
    data class PlaceStreamPlaybackGetVideoPlaylistOutput(
        @SerialName("data")
        val `data`: ByteArray    )

/**
 * Get the HLS playlist for a video
 *
 * Endpoint: place.stream.playback.getVideoPlaylist
 */
suspend fun ATProtoClient.Place.Stream.Playback.getVideoPlaylist(
parameters: PlaceStreamPlaybackGetVideoPlaylistParameters): ATProtoResponse<PlaceStreamPlaybackGetVideoPlaylistOutput> {
    val endpoint = "place.stream.playback.getVideoPlaylist"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/vnd.apple.mpegurl"),
        body = null
    )
}
