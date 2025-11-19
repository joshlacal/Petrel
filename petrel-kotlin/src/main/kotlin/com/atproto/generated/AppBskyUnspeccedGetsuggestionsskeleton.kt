// Lexicon: 1, ID: app.bsky.unspecced.getSuggestionsSkeleton
// Get a skeleton of suggested actors. Intended to be called and then hydrated through app.bsky.actor.getSuggestions
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetsuggestionsskeleton {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestionsSkeleton"

    @Serializable
    data class Parameters(
// DID of the account making the request (not included for public/unauthenticated queries). Used to boost followed accounts in ranking.        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,// DID of the account to get suggestions relative to. If not provided, suggestions will be based on the viewer.        @SerialName("relativeToDid")
        val relativeToDid: DID? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("actors")
        val actors: List<AppBskyUnspeccedDefs.Skeletonsearchactor>,// DID of the account these suggestions are relative to. If this is returned undefined, suggestions are based on the viewer.        @SerialName("relativeToDid")
        val relativeToDid: DID? = null,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recId")
        val recId: Int? = null    )

}

/**
 * Get a skeleton of suggested actors. Intended to be called and then hydrated through app.bsky.actor.getSuggestions
 *
 * Endpoint: app.bsky.unspecced.getSuggestionsSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getsuggestionsskeleton(
parameters: AppBskyUnspeccedGetsuggestionsskeleton.Parameters): ATProtoResponse<AppBskyUnspeccedGetsuggestionsskeleton.Output> {
    val endpoint = "app.bsky.unspecced.getSuggestionsSkeleton"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
