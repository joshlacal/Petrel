// Lexicon: 1, ID: app.bsky.unspecced.getOnboardingSuggestedStarterPacks
// Get a list of suggested starterpacks for onboarding
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetonboardingsuggestedstarterpacks {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getOnboardingSuggestedStarterPacks"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefs.Starterpackview>    )

}

/**
 * Get a list of suggested starterpacks for onboarding
 *
 * Endpoint: app.bsky.unspecced.getOnboardingSuggestedStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getonboardingsuggestedstarterpacks(
parameters: AppBskyUnspeccedGetonboardingsuggestedstarterpacks.Parameters): ATProtoResponse<AppBskyUnspeccedGetonboardingsuggestedstarterpacks.Output> {
    val endpoint = "app.bsky.unspecced.getOnboardingSuggestedStarterPacks"

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
