// Lexicon: 1, ID: app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton
// Get a skeleton of suggested starterpacks for onboarding. Intended to be called and hydrated by app.bsky.unspecced.getOnboardingSuggestedStarterPacks
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetOnboardingSuggestedStarterPacksSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton"
}

@Serializable
    data class AppBskyUnspeccedGetOnboardingSuggestedStarterPacksSkeletonParameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetOnboardingSuggestedStarterPacksSkeletonOutput(
        @SerialName("starterPacks")
        val starterPacks: List<ATProtocolURI>    )

/**
 * Get a skeleton of suggested starterpacks for onboarding. Intended to be called and hydrated by app.bsky.unspecced.getOnboardingSuggestedStarterPacks
 *
 * Endpoint: app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getOnboardingSuggestedStarterPacksSkeleton(
parameters: AppBskyUnspeccedGetOnboardingSuggestedStarterPacksSkeletonParameters): ATProtoResponse<AppBskyUnspeccedGetOnboardingSuggestedStarterPacksSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
