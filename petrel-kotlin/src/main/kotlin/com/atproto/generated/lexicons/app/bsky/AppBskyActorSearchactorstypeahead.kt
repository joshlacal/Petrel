// Lexicon: 1, ID: app.bsky.actor.searchActorsTypeahead
// Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyActorSearchActorsTypeaheadDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.searchActorsTypeahead"
}

@Serializable
    data class AppBskyActorSearchActorsTypeaheadParameters(
// DEPRECATED: use 'q' instead.        @SerialName("term")
        val term: String? = null,// Search query prefix; not a full query string.        @SerialName("q")
        val q: String? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyActorSearchActorsTypeaheadOutput(
        @SerialName("actors")
        val actors: List<AppBskyActorDefsProfileViewBasic>    )

/**
 * Find actor suggestions for a prefix search term. Expected use is for auto-completion during text field entry. Does not require auth.
 *
 * Endpoint: app.bsky.actor.searchActorsTypeahead
 */
suspend fun ATProtoClient.App.Bsky.Actor.searchActorsTypeahead(
parameters: AppBskyActorSearchActorsTypeaheadParameters): ATProtoResponse<AppBskyActorSearchActorsTypeaheadOutput> {
    val endpoint = "app.bsky.actor.searchActorsTypeahead"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
