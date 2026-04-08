// Lexicon: 1, ID: place.stream.ingest.getIngestUrls
// Get ingest URLs for a Streamplace station.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamIngestGetIngestUrlsDefs {
    const val TYPE_IDENTIFIER = "place.stream.ingest.getIngestUrls"
}

@Serializable
sealed interface PlaceStreamIngestGetIngestUrlsOutputIngestsUnion {
    @Serializable
    @SerialName("place.stream.ingest.getIngestUrls#PlaceStreamIngestDefsIngest")
    data class PlaceStreamIngestDefsIngest(val value: PlaceStreamIngestDefsIngest) : PlaceStreamIngestGetIngestUrlsOutputIngestsUnion

    @Serializable
    @SerialName("unknown")
    data class Unexpected(val value: JsonElement) : PlaceStreamIngestGetIngestUrlsOutputIngestsUnion
}

@Serializable
    class PlaceStreamIngestGetIngestUrlsParameters

    @Serializable
    data class PlaceStreamIngestGetIngestUrlsOutput(
        @SerialName("ingests")
        val ingests: List<PlaceStreamIngestGetIngestUrlsOutputIngestsUnion>    )

/**
 * Get ingest URLs for a Streamplace station.
 *
 * Endpoint: place.stream.ingest.getIngestUrls
 */
suspend fun ATProtoClient.Place.Stream.Ingest.getIngestUrls(
parameters: PlaceStreamIngestGetIngestUrlsParameters): ATProtoResponse<PlaceStreamIngestGetIngestUrlsOutput> {
    val endpoint = "place.stream.ingest.getIngestUrls"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
