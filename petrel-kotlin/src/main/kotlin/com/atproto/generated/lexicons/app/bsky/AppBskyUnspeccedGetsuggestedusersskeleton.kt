// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedUsersSkeleton
// Get a skeleton of suggested users. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsers
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedUsersSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedUsersSkeleton"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedUsersSkeletonParameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,// Category of users to get suggestions for.        @SerialName("category")
        val category: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedUsersSkeletonOutput(
        @SerialName("dids")
        val dids: List<DID>    )

/**
 * Get a skeleton of suggested users. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsers
 *
 * Endpoint: app.bsky.unspecced.getSuggestedUsersSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedUsersSkeleton(
parameters: AppBskyUnspeccedGetSuggestedUsersSkeletonParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedUsersSkeletonOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedUsersSkeleton"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
