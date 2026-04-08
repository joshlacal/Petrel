// Lexicon: 1, ID: place.stream.server.getServerTime
// Get the current server time for client clock synchronization
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamServerGetServerTimeDefs {
    const val TYPE_IDENTIFIER = "place.stream.server.getServerTime"
}

@Serializable
    class PlaceStreamServerGetServerTimeParameters

    @Serializable
    data class PlaceStreamServerGetServerTimeOutput(
// Current server time in RFC3339 format        @SerialName("serverTime")
        val serverTime: ATProtocolDate    )

/**
 * Get the current server time for client clock synchronization
 *
 * Endpoint: place.stream.server.getServerTime
 */
suspend fun ATProtoClient.Place.Stream.Server.getServerTime(
parameters: PlaceStreamServerGetServerTimeParameters): ATProtoResponse<PlaceStreamServerGetServerTimeOutput> {
    val endpoint = "place.stream.server.getServerTime"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
