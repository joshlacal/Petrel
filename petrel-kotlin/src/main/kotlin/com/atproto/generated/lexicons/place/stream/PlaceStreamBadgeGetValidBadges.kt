// Lexicon: 1, ID: place.stream.badge.getValidBadges
// Get valid badges for the authenticated user, optionally in the context of a specific streamer's chat
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object PlaceStreamBadgeGetValidBadgesDefs {
    const val TYPE_IDENTIFIER = "place.stream.badge.getValidBadges"
}

@Serializable
    data class PlaceStreamBadgeGetValidBadgesParameters(
// Optional DID of the streamer for context-specific badges (mod, vip, etc)        @SerialName("streamer")
        val streamer: DID? = null    )

    @Serializable
    data class PlaceStreamBadgeGetValidBadgesOutput(
        @SerialName("badges")
        val badges: List<PlaceStreamBadgeDefsBadgeView>    )

/**
 * Get valid badges for the authenticated user, optionally in the context of a specific streamer's chat
 *
 * Endpoint: place.stream.badge.getValidBadges
 */
suspend fun ATProtoClient.Place.Stream.Badge.getValidBadges(
parameters: PlaceStreamBadgeGetValidBadgesParameters): ATProtoResponse<PlaceStreamBadgeGetValidBadgesOutput> {
    val endpoint = "place.stream.badge.getValidBadges"

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
