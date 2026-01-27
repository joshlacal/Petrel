// Lexicon: 1, ID: app.bsky.unspecced.searchStarterPacksSkeleton
// Backend Starter Pack search, returns only skeleton.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedSearchStarterPacksSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.searchStarterPacksSkeleton"
}

@Serializable
    data class AppBskyUnspeccedSearchStarterPacksSkeletonParameters(
// Search query string; syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.        @SerialName("q")
        val q: String,// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null,// Optional pagination mechanism; may not necessarily allow scrolling through entire result set.        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyUnspeccedSearchStarterPacksSkeletonOutput(
        @SerialName("cursor")
        val cursor: String? = null,// Count of search hits. Optional, may be rounded/truncated, and may not be possible to paginate through all hits.        @SerialName("hitsTotal")
        val hitsTotal: Int? = null,        @SerialName("starterPacks")
        val starterPacks: List<AppBskyUnspeccedDefsSkeletonSearchStarterPack>    )

sealed class AppBskyUnspeccedSearchStarterPacksSkeletonError(val name: String, val description: String?) {
        object BadQueryString: AppBskyUnspeccedSearchStarterPacksSkeletonError("BadQueryString", "")
    }

/**
 * Backend Starter Pack search, returns only skeleton.
 *
 * Endpoint: app.bsky.unspecced.searchStarterPacksSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.searchStarterPacksSkeleton(
parameters: AppBskyUnspeccedSearchStarterPacksSkeletonParameters): ATProtoResponse<AppBskyUnspeccedSearchStarterPacksSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.searchStarterPacksSkeleton"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
