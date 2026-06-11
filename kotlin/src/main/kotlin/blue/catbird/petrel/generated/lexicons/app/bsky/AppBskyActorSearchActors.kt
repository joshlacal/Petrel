// Lexicon: 1, ID: app.bsky.actor.searchActors
// Find actors (profiles) matching search criteria. Does not require auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyActorSearchActorsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.searchActors"
}

@Serializable
    data class AppBskyActorSearchActorsParameters(
// DEPRECATED: use 'q' instead.        @SerialName("term")
        val term: String? = null,// Search query string. Syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.        @SerialName("q")
        val q: String? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyActorSearchActorsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("actors")
        val actors: List<AppBskyActorDefsProfileView>    )

/**
 * Find actors (profiles) matching search criteria. Does not require auth.
 *
 * Endpoint: app.bsky.actor.searchActors
 */
suspend fun ATProtoClient.App.Bsky.Actor.searchActors(
parameters: AppBskyActorSearchActorsParameters): ATProtoResponse<AppBskyActorSearchActorsOutput> {
    val endpoint = "app.bsky.actor.searchActors"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
