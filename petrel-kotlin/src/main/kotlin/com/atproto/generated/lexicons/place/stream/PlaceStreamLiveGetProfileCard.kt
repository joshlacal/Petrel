// Lexicon: 1, ID: place.stream.live.getProfileCard
// Get an OG image associated with a given account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamLiveGetProfileCardDefs {
    const val TYPE_IDENTIFIER = "place.stream.live.getProfileCard"
}

@Serializable
    data class PlaceStreamLiveGetProfileCardParameters(
// The DID or handle of the account.        @SerialName("id")
        val id: String    )

    @Serializable
    data class PlaceStreamLiveGetProfileCardOutput(
        @SerialName("data")
        val `data`: ByteArray    )

sealed class PlaceStreamLiveGetProfileCardError(val name: String, val description: String?) {
        object RepoNotFound: PlaceStreamLiveGetProfileCardError("RepoNotFound", "")
    }

/**
 * Get an OG image associated with a given account.
 *
 * Endpoint: place.stream.live.getProfileCard
 */
suspend fun ATProtoClient.Place.Stream.Live.getProfileCard(
parameters: PlaceStreamLiveGetProfileCardParameters): ATProtoResponse<PlaceStreamLiveGetProfileCardOutput> {
    val endpoint = "place.stream.live.getProfileCard"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "*/*"),
        body = null
    )
}
