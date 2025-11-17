// Lexicon: 1, ID: app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton
// Get a skeleton of suggested starterpacks for onboarding. Intended to be called and hydrated by app.bsky.unspecced.getOnboardingSuggestedStarterPacks
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetonboardingsuggestedstarterpacksskeleton {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton"

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
 * Get a skeleton of suggested starterpacks for onboarding. Intended to be called and hydrated by app.bsky.unspecced.getOnboardingSuggestedStarterPacks
 *
 * Endpoint: app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getonboardingsuggestedstarterpacksskeleton(
parameters: AppBskyUnspeccedGetonboardingsuggestedstarterpacksskeleton.Parameters): ATProtoResponse<AppBskyUnspeccedGetonboardingsuggestedstarterpacksskeleton.Output> {
    val endpoint = "app.bsky.unspecced.getOnboardingSuggestedStarterPacksSkeleton"

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
