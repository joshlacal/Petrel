// Lexicon: 1, ID: app.bsky.unspecced.searchActorsSkeleton
// Backend Actors (profile) search, returns only skeleton.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedSearchactorsskeleton {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.searchActorsSkeleton"

    @Serializable
    data class Parameters(
// Search query string; syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended. For typeahead search, only simple term match is supported, not full syntax.        @SerialName("q")
        val q: String,// DID of the account making the request (not included for public/unauthenticated queries). Used to boost followed accounts in ranking.        @SerialName("viewer")
        val viewer: DID? = null,// If true, acts as fast/simple 'typeahead' query.        @SerialName("typeahead")
        val typeahead: Boolean? = null,        @SerialName("limit")
        val limit: Int? = null,// Optional pagination mechanism; may not necessarily allow scrolling through entire result set.        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,// Count of search hits. Optional, may be rounded/truncated, and may not be possible to paginate through all hits.        @SerialName("hitsTotal")
        val hitsTotal: Int? = null,        @SerialName("actors")
        val actors: List<AppBskyUnspeccedDefs.Skeletonsearchactor>    )

    sealed class Error(val name: String, val description: String?) {
        object Badquerystring: Error("BadQueryString", "")
    }

}

/**
 * Backend Actors (profile) search, returns only skeleton.
 *
 * Endpoint: app.bsky.unspecced.searchActorsSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.searchactorsskeleton(
parameters: AppBskyUnspeccedSearchactorsskeleton.Parameters): ATProtoResponse<AppBskyUnspeccedSearchactorsskeleton.Output> {
    val endpoint = "app.bsky.unspecced.searchActorsSkeleton"

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
