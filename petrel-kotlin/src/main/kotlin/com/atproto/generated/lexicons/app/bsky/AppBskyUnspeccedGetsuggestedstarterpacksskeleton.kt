// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedStarterPacksSkeleton
// Get a skeleton of suggested starterpacks. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedStarterpacks
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedStarterPacksSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedStarterPacksSkeleton"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedStarterPacksSkeletonParameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedStarterPacksSkeletonOutput(
        @SerialName("starterPacks")
        val starterPacks: List<ATProtocolURI>    )

/**
 * Get a skeleton of suggested starterpacks. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedStarterpacks
 *
 * Endpoint: app.bsky.unspecced.getSuggestedStarterPacksSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedStarterPacksSkeleton(
parameters: AppBskyUnspeccedGetSuggestedStarterPacksSkeletonParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedStarterPacksSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedStarterPacksSkeleton"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
