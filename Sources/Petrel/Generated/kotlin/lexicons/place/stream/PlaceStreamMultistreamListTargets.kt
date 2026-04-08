// Lexicon: 1, ID: place.stream.multistream.listTargets
// List a range of targets for rebroadcasting a Streamplace stream.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMultistreamListTargetsDefs {
    const val TYPE_IDENTIFIER = "place.stream.multistream.listTargets"
}

    @Serializable
    data class PlaceStreamMultistreamListTargetsRecord(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID,        @SerialName("value")
        val value: JsonElement    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamMultistreamListTargetsRecord"
        }
    }

@Serializable
    data class PlaceStreamMultistreamListTargetsParameters(
// The number of targets to return.        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class PlaceStreamMultistreamListTargetsOutput(
        @SerialName("targets")
        val targets: List<PlaceStreamMultistreamDefsTargetView>,        @SerialName("cursor")
        val cursor: String? = null    )

/**
 * List a range of targets for rebroadcasting a Streamplace stream.
 *
 * Endpoint: place.stream.multistream.listTargets
 */
suspend fun ATProtoClient.Place.Stream.Multistream.listTargets(
parameters: PlaceStreamMultistreamListTargetsParameters): ATProtoResponse<PlaceStreamMultistreamListTargetsOutput> {
    val endpoint = "place.stream.multistream.listTargets"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
