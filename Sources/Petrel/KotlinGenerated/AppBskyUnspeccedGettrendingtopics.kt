// Lexicon: 1, ID: app.bsky.unspecced.getTrendingTopics
// Get a list of trending topics
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGettrendingtopics {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getTrendingTopics"

    @Serializable
    data class Parameters(
// DID of the account making the request (not included for public/unauthenticated queries). Used to boost followed accounts in ranking.        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("topics")
        val topics: List<AppBskyUnspeccedDefs.Trendingtopic>,        @SerialName("suggested")
        val suggested: List<AppBskyUnspeccedDefs.Trendingtopic>    )

}

/**
 * Get a list of trending topics
 *
 * Endpoint: app.bsky.unspecced.getTrendingTopics
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.gettrendingtopics(
parameters: AppBskyUnspeccedGettrendingtopics.Parameters): ATProtoResponse<AppBskyUnspeccedGettrendingtopics.Output> {
    val endpoint = "app.bsky.unspecced.getTrendingTopics"

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
