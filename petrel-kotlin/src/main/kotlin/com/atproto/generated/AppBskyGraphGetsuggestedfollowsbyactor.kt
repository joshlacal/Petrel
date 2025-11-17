// Lexicon: 1, ID: app.bsky.graph.getSuggestedFollowsByActor
// Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphGetsuggestedfollowsbyactor {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getSuggestedFollowsByActor"

    @Serializable
    data class Parameters(
        @SerialName("actor")
        val actor: ATIdentifier    )

        @Serializable
    data class Output(
        @SerialName("suggestions")
        val suggestions: List<AppBskyActorDefs.Profileview>,// If true, response has fallen-back to generic results, and is not scoped using relativeToDid        @SerialName("isFallback")
        val isFallback: Boolean? = null,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recId")
        val recId: Int? = null    )

}

/**
 * Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.
 *
 * Endpoint: app.bsky.graph.getSuggestedFollowsByActor
 */
suspend fun ATProtoClient.App.Bsky.Graph.getsuggestedfollowsbyactor(
parameters: AppBskyGraphGetsuggestedfollowsbyactor.Parameters): ATProtoResponse<AppBskyGraphGetsuggestedfollowsbyactor.Output> {
    val endpoint = "app.bsky.graph.getSuggestedFollowsByActor"

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
