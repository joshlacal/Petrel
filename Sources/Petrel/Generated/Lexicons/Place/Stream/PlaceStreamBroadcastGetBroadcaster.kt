// Lexicon: 1, ID: place.stream.broadcast.getBroadcaster
// Get information about a Streamplace broadcaster.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamBroadcastGetBroadcasterDefs {
    const val TYPE_IDENTIFIER = "place.stream.broadcast.getBroadcaster"
}

@Serializable
    class PlaceStreamBroadcastGetBroadcasterParameters

    @Serializable
    data class PlaceStreamBroadcastGetBroadcasterOutput(
// DID of the Streamplace broadcaster to which this server belongs        @SerialName("broadcaster")
        val broadcaster: DID,// DID of this particular Streamplace server        @SerialName("server")
        val server: DID? = null,// Array of DIDs authorized as admins        @SerialName("admins")
        val admins: List<DID>? = null    )

/**
 * Get information about a Streamplace broadcaster.
 *
 * Endpoint: place.stream.broadcast.getBroadcaster
 */
suspend fun ATProtoClient.Place.Stream.Broadcast.getBroadcaster(
parameters: PlaceStreamBroadcastGetBroadcasterParameters): ATProtoResponse<PlaceStreamBroadcastGetBroadcasterOutput> {
    val endpoint = "place.stream.broadcast.getBroadcaster"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
