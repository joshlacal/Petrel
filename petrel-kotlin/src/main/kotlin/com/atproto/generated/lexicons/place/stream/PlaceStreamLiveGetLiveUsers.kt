// Lexicon: 1, ID: place.stream.live.getLiveUsers
// Get a list of livestream segments for a user
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveGetLiveUsersDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.getLiveUsers"
}

@Serializable
    data class PlaceStreamLiveGetLiveUsersParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("before")
        val before: ATProtocolDate? = null    )

    @Serializable
    data class PlaceStreamLiveGetLiveUsersOutput(
        @SerialName("streams")
        val streams: List<PlaceStreamLivestreamLivestreamView>? = null    )

/**
 * Get a list of livestream segments for a user
 *
 * Endpoint: place.stream.live.getLiveUsers
 */
suspend fun ATProtoClient.Place.Stream.Live.getLiveUsers(
parameters: PlaceStreamLiveGetLiveUsersParameters): ATProtoResponse<PlaceStreamLiveGetLiveUsersOutput> {
    val endpoint = "place.stream.live.getLiveUsers"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
