// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedStarterPacks
// Get a list of suggested starterpacks
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetsuggestedstarterpacks {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedStarterPacks"

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
 * Get a list of suggested starterpacks
 *
 * Endpoint: app.bsky.unspecced.getSuggestedStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getsuggestedstarterpacks(
parameters: AppBskyUnspeccedGetsuggestedstarterpacks.Parameters): ATProtoResponse<AppBskyUnspeccedGetsuggestedstarterpacks.Output> {
    val endpoint = "app.bsky.unspecced.getSuggestedStarterPacks"

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
