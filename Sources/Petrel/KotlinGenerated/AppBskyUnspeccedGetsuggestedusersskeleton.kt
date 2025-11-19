// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedUsersSkeleton
// Get a skeleton of suggested users. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsers
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetsuggestedusersskeleton {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedUsersSkeleton"

    @Serializable
    data class Parameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,// Category of users to get suggestions for.        @SerialName("category")
        val category: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("dids")
        val dids: List<DID>    )

}

/**
 * Get a skeleton of suggested users. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedUsers
 *
 * Endpoint: app.bsky.unspecced.getSuggestedUsersSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getsuggestedusersskeleton(
parameters: AppBskyUnspeccedGetsuggestedusersskeleton.Parameters): ATProtoResponse<AppBskyUnspeccedGetsuggestedusersskeleton.Output> {
    val endpoint = "app.bsky.unspecced.getSuggestedUsersSkeleton"

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
