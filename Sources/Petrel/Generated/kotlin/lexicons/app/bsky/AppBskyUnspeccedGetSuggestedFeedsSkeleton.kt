// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedFeedsSkeleton
// Get a skeleton of suggested feeds. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedFeeds
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedFeedsSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedFeedsSkeleton"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedFeedsSkeletonParameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedFeedsSkeletonOutput(
        @SerialName("feeds")
        val feeds: List<ATProtocolURI>    )

/**
 * Get a skeleton of suggested feeds. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedFeeds
 *
 * Endpoint: app.bsky.unspecced.getSuggestedFeedsSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedFeedsSkeleton(
parameters: AppBskyUnspeccedGetSuggestedFeedsSkeletonParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedFeedsSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedFeedsSkeleton"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
