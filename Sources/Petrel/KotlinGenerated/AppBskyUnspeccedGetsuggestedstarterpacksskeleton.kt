// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedStarterPacksSkeleton
// Get a skeleton of suggested starterpacks. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedStarterpacks
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetsuggestedstarterpacksskeleton {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedStarterPacksSkeleton"

    @Serializable
    data class Parameters(
// DID of the account making the request (not included for public/unauthenticated queries).        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("starterPacks")
        val starterPacks: List<ATProtocolURI>    )

}

/**
 * Get a skeleton of suggested starterpacks. Intended to be called and hydrated by app.bsky.unspecced.getSuggestedStarterpacks
 *
 * Endpoint: app.bsky.unspecced.getSuggestedStarterPacksSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getsuggestedstarterpacksskeleton(
parameters: AppBskyUnspeccedGetsuggestedstarterpacksskeleton.Parameters): ATProtoResponse<AppBskyUnspeccedGetsuggestedstarterpacksskeleton.Output> {
    val endpoint = "app.bsky.unspecced.getSuggestedStarterPacksSkeleton"

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
