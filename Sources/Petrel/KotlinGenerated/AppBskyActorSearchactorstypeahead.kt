// Lexicon: 1, ID: app.bsky.actor.searchActorsTypeahead
// Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyActorSearchactorstypeahead {
    const val TYPE_IDENTIFIER = "app.bsky.actor.searchActorsTypeahead"

    @Serializable
    data class Parameters(
// DEPRECATED: use 'q' instead.        @SerialName("term")
        val term: String? = null,// Search query prefix; not a full query string.        @SerialName("q")
        val q: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

        @Serializable
    data class Output(
        @SerialName("actors")
        val actors: List<AppBskyActorDefs.Profileviewbasic>    )

}

/**
 * Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.
 *
 * Endpoint: app.bsky.actor.searchActorsTypeahead
 */
suspend fun ATProtoClient.App.Bsky.Actor.searchactorstypeahead(
parameters: AppBskyActorSearchactorstypeahead.Parameters): ATProtoResponse<AppBskyActorSearchactorstypeahead.Output> {
    val endpoint = "app.bsky.actor.searchActorsTypeahead"

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
