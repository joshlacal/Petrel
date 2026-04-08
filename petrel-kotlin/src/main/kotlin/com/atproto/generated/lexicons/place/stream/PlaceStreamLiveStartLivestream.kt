// Lexicon: 1, ID: place.stream.live.startLivestream
// Create a new place.stream.livestream record, automatically populating a thumbnail and creating a Bluesky post and whatnot. You can do this manually by creating a record but this method can work better for mobile livestreaming and such.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveStartLivestreamDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.startLivestream"
}

@Serializable
    data class PlaceStreamLiveStartLivestreamInput(
        @SerialName("livestream")
        val livestream: PlaceStreamLivestream,// The DID of the streamer.        @SerialName("streamer")
        val streamer: DID,// Whether to create a Bluesky post announcing the livestream.        @SerialName("createBlueskyPost")
        val createBlueskyPost: Boolean? = null    )

    @Serializable
    data class PlaceStreamLiveStartLivestreamOutput(
// The URI of the livestream record.        @SerialName("uri")
        val uri: URI,// The CID of the livestream record.        @SerialName("cid")
        val cid: CID    )

/**
 * Create a new place.stream.livestream record, automatically populating a thumbnail and creating a Bluesky post and whatnot. You can do this manually by creating a record but this method can work better for mobile livestreaming and such.
 *
 * Endpoint: place.stream.live.startLivestream
 */
suspend fun ATProtoClient.Place.Stream.Live.startLivestream(
input: PlaceStreamLiveStartLivestreamInput): ATProtoResponse<PlaceStreamLiveStartLivestreamOutput> {
    val endpoint = "place.stream.live.startLivestream"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
