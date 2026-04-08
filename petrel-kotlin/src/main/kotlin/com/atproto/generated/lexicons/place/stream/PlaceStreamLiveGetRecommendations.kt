// Lexicon: 1, ID: place.stream.live.getRecommendations
// Get the list of streamers recommended by a user
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveGetRecommendationsDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.getRecommendations"
}

@Serializable
sealed interface PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion {
    @Serializable
    @SerialName("place.stream.live.getRecommendations#PlaceStreamLiveGetRecommendationsLivestreamRecommendation")
    data class PlaceStreamLiveGetRecommendationsLivestreamRecommendation(val value: PlaceStreamLiveGetRecommendationsLivestreamRecommendation) : PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion
}

    @Serializable
    data class PlaceStreamLiveGetRecommendationsLivestreamRecommendation(
/** The DID of the recommended streamer */        @SerialName("did")
        val did: DID,/** Source of the recommendation */        @SerialName("source")
        val source: String    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamLiveGetRecommendationsLivestreamRecommendation"
        }
    }

@Serializable
    data class PlaceStreamLiveGetRecommendationsParameters(
// The DID of the user whose recommendations to fetch        @SerialName("userDID")
        val userDID: DID    )

    @Serializable
    data class PlaceStreamLiveGetRecommendationsOutput(
// Ordered list of recommendations        @SerialName("recommendations")
        val recommendations: List<PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion>,// The user DID this recommendation is for        @SerialName("userDID")
        val userDID: DID? = null    )

/**
 * Get the list of streamers recommended by a user
 *
 * Endpoint: place.stream.live.getRecommendations
 */
suspend fun ATProtoClient.Place.Stream.Live.getRecommendations(
parameters: PlaceStreamLiveGetRecommendationsParameters): ATProtoResponse<PlaceStreamLiveGetRecommendationsOutput> {
    val endpoint = "place.stream.live.getRecommendations"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
