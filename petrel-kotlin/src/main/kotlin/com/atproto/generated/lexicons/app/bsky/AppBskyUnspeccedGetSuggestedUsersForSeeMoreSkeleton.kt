// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton
// Get a skeleton of suggested users for the See More page. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsersForSeeMore
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import com.atproto.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedUsersForSeeMoreSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedUsersForSeeMoreSkeletonParameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,// Category of users to get suggestions for.        @SerialName("category")
        val category: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedUsersForSeeMoreSkeletonOutput(
        @SerialName("dids")
        val dids: List<DID>,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recIdStr")
        val recIdStr: String? = null    )

/**
 * Get a skeleton of suggested users for the See More page. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsersForSeeMore
 *
 * Endpoint: app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedUsersForSeeMoreSkeleton(
parameters: AppBskyUnspeccedGetSuggestedUsersForSeeMoreSkeletonParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedUsersForSeeMoreSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedUsersForSeeMoreSkeleton"

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
