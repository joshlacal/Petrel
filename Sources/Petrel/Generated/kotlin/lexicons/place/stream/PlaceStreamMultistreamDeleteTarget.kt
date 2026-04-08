// Lexicon: 1, ID: place.stream.multistream.deleteTarget
// Delete a target for rebroadcasting a Streamplace stream.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMultistreamDeleteTargetDefs {
    const val TYPE_IDENTIFIER = "place.stream.multistream.deleteTarget"
}

@Serializable
    data class PlaceStreamMultistreamDeleteTargetInput(
// The Record Key of the target to delete.        @SerialName("rkey")
        val rkey: String    )

    @Serializable
    class PlaceStreamMultistreamDeleteTargetOutput

/**
 * Delete a target for rebroadcasting a Streamplace stream.
 *
 * Endpoint: place.stream.multistream.deleteTarget
 */
suspend fun ATProtoClient.Place.Stream.Multistream.deleteTarget(
input: PlaceStreamMultistreamDeleteTargetInput): ATProtoResponse<PlaceStreamMultistreamDeleteTargetOutput> {
    val endpoint = "place.stream.multistream.deleteTarget"

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
