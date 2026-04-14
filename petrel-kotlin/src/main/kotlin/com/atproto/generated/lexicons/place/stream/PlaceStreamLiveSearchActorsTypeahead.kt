// Lexicon: 1, ID: place.stream.live.searchActorsTypeahead
// Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveSearchActorsTypeaheadDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.searchActorsTypeahead"
}

    @Serializable
    data class PlaceStreamLiveSearchActorsTypeaheadActor(
/** The actor's DID */        @SerialName("did")
        val did: DID,/** The actor's handle */        @SerialName("handle")
        val handle: Handle    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#placeStreamLiveSearchActorsTypeaheadActor"
        }
    }

@Serializable
    data class PlaceStreamLiveSearchActorsTypeaheadParameters(
// Search query prefix; not a full query string.        @SerialName("q")
        val q: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class PlaceStreamLiveSearchActorsTypeaheadOutput(
        @SerialName("actors")
        val actors: List<PlaceStreamLiveSearchActorsTypeaheadActor>    )

/**
 * Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry.
 *
 * Endpoint: place.stream.live.searchActorsTypeahead
 */
suspend fun ATProtoClient.Place.Stream.Live.searchActorsTypeahead(
parameters: PlaceStreamLiveSearchActorsTypeaheadParameters): ATProtoResponse<PlaceStreamLiveSearchActorsTypeaheadOutput> {
    val endpoint = "place.stream.live.searchActorsTypeahead"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
