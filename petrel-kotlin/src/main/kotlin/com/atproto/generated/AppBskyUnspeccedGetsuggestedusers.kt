// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedUsers
// Get a list of suggested users
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyUnspeccedGetsuggestedusers {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedUsers"

    @Serializable
    data class Parameters(
// Category of users to get suggestions for.        @SerialName("category")
        val category: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("actors")
        val actors: List<AppBskyActorDefs.Profileview>    )

}

/**
 * Get a list of suggested users
 *
 * Endpoint: app.bsky.unspecced.getSuggestedUsers
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getsuggestedusers(
parameters: AppBskyUnspeccedGetsuggestedusers.Parameters): ATProtoResponse<AppBskyUnspeccedGetsuggestedusers.Output> {
    val endpoint = "app.bsky.unspecced.getSuggestedUsers"

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
