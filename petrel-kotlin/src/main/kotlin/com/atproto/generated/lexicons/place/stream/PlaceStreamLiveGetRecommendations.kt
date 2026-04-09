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

@Serializable(with = PlaceStreamLiveGetRecommendationsOutputRecommendationsUnionSerializer::class)
sealed interface PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion {
    @Serializable
    data class LivestreamRecommendation(val value: com.atproto.generated.PlaceStreamLiveGetRecommendationsLivestreamRecommendation) : PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion

    @Serializable
    data class Unexpected(val value: JsonElement) : PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion
}

object PlaceStreamLiveGetRecommendationsOutputRecommendationsUnionSerializer : kotlinx.serialization.KSerializer<PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion> {
    override val descriptor: kotlinx.serialization.descriptors.SerialDescriptor =
        kotlinx.serialization.descriptors.buildClassSerialDescriptor("PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion")

    override fun serialize(encoder: kotlinx.serialization.encoding.Encoder, value: PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion) {
        val jsonEncoder = encoder as kotlinx.serialization.json.JsonEncoder
        val element = when (value) {
            is PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion.LivestreamRecommendation -> {
                val obj = jsonEncoder.json.encodeToJsonElement(com.atproto.generated.PlaceStreamLiveGetRecommendationsLivestreamRecommendation.serializer(), value.value)
                kotlinx.serialization.json.JsonObject(obj.jsonObject.toMutableMap().also {
                    it["\$type"] = kotlinx.serialization.json.JsonPrimitive("place.stream.live.getRecommendations#livestreamRecommendation")
                })
            }
            is PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion.Unexpected -> value.value
        }
        jsonEncoder.encodeJsonElement(element)
    }

    override fun deserialize(decoder: kotlinx.serialization.encoding.Decoder): PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion {
        val jsonDecoder = decoder as kotlinx.serialization.json.JsonDecoder
        val element = jsonDecoder.decodeJsonElement()
        val jsonObject = element.jsonObject
        val type = jsonObject["\$type"]?.jsonPrimitive?.contentOrNull

        return when (type) {
            "place.stream.live.getRecommendations#livestreamRecommendation" -> PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion.LivestreamRecommendation(
                jsonDecoder.json.decodeFromJsonElement(com.atproto.generated.PlaceStreamLiveGetRecommendationsLivestreamRecommendation.serializer(), element)
            )
            else -> PlaceStreamLiveGetRecommendationsOutputRecommendationsUnion.Unexpected(element)
        }
    }
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
