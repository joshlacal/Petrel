// Lexicon: 1, ID: app.bsky.actor.searchActors
// Find actors (profiles) matching search criteria. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyActorSearchactors {
    const val TYPE_IDENTIFIER = "app.bsky.actor.searchActors"

    @Serializable
    data class Parameters(
// DEPRECATED: use 'q' instead.        @SerialName("term")
        val term: String? = null,// Search query string. Syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.        @SerialName("q")
        val q: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("actors")
        val actors: List<AppBskyActorDefs.Profileview>    )

}

/**
 * Find actors (profiles) matching search criteria. Does not require auth.
 *
 * Endpoint: app.bsky.actor.searchActors
 */
suspend fun ATProtoClient.App.Bsky.Actor.searchactors(
parameters: AppBskyActorSearchactors.Parameters): ATProtoResponse<AppBskyActorSearchactors.Output> {
    val endpoint = "app.bsky.actor.searchActors"

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
