// Lexicon: 1, ID: place.stream.multistream.putTarget
// Update an existing target for rebroadcasting a Streamplace stream.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamMultistreamPutTargetDefs {
    const val TYPE_IDENTIFIER = "place.stream.multistream.putTarget"
}

@Serializable
    data class PlaceStreamMultistreamPutTargetInput(
        @SerialName("multistreamTarget")
        val multistreamTarget: PlaceStreamMultistreamTarget,// The Record Key.        @SerialName("rkey")
        val rkey: String? = null    )

    typealias PlaceStreamMultistreamPutTargetOutput = PlaceStreamMultistreamDefsTargetView

sealed class PlaceStreamMultistreamPutTargetError(val name: String, val description: String?) {
        object InvalidTargetUrl: PlaceStreamMultistreamPutTargetError("InvalidTargetUrl", "The provided target URL is invalid or unreachable.")
    }

/**
 * Update an existing target for rebroadcasting a Streamplace stream.
 *
 * Endpoint: place.stream.multistream.putTarget
 */
suspend fun ATProtoClient.Place.Stream.Multistream.putTarget(
input: PlaceStreamMultistreamPutTargetInput): ATProtoResponse<PlaceStreamMultistreamPutTargetOutput> {
    val endpoint = "place.stream.multistream.putTarget"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
