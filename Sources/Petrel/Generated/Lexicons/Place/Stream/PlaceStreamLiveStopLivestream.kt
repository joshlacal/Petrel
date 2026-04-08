// Lexicon: 1, ID: place.stream.live.stopLivestream
// Stop your current livestream, updating your current place.stream.livestream record and ceasing the flow of video.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveStopLivestreamDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.stopLivestream"
}

@Serializable
    class PlaceStreamLiveStopLivestreamInput

    @Serializable
    data class PlaceStreamLiveStopLivestreamOutput(
// The URI of the stopped livestream record.        @SerialName("uri")
        val uri: URI,// The new CID of the stopped livestream record.        @SerialName("cid")
        val cid: CID    )

/**
 * Stop your current livestream, updating your current place.stream.livestream record and ceasing the flow of video.
 *
 * Endpoint: place.stream.live.stopLivestream
 */
suspend fun ATProtoClient.Place.Stream.Live.stopLivestream(
input: PlaceStreamLiveStopLivestreamInput): ATProtoResponse<PlaceStreamLiveStopLivestreamOutput> {
    val endpoint = "place.stream.live.stopLivestream"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
