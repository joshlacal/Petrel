// Lexicon: 1, ID: app.bsky.unspecced.getTrendsSkeleton
// Get the skeleton of trends on the network. Intended to be called and then hydrated through app.bsky.unspecced.getTrends
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetTrendsSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getTrendsSkeleton"
}

@Serializable
    data class AppBskyUnspeccedGetTrendsSkeletonParameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetTrendsSkeletonOutput(
        @SerialName("trends")
        val trends: List<AppBskyUnspeccedDefsSkeletonTrend>    )

/**
 * Get the skeleton of trends on the network. Intended to be called and then hydrated through app.bsky.unspecced.getTrends
 *
 * Endpoint: app.bsky.unspecced.getTrendsSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getTrendsSkeleton(
parameters: AppBskyUnspeccedGetTrendsSkeletonParameters): ATProtoResponse<AppBskyUnspeccedGetTrendsSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.getTrendsSkeleton"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
