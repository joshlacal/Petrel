// Lexicon: 1, ID: app.bsky.graph.searchStarterPacksV2
// Find starter packs matching search criteria. Does not require auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphSearchStarterPacksV2Defs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.searchStarterPacksV2"
}

@Serializable
    data class AppBskyGraphSearchStarterPacksV2Parameters(
// Search query string. Syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.        @SerialName("q")
        val q: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphSearchStarterPacksV2Output(
        @SerialName("cursor")
        val cursor: String? = null,// Estimated total number of matching hits. May be rounded or truncated.        @SerialName("hitsTotal")
        val hitsTotal: Int? = null,        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefsStarterPackView>    )

/**
 * Find starter packs matching search criteria. Does not require auth.
 *
 * Endpoint: app.bsky.graph.searchStarterPacksV2
 */
suspend fun ATProtoClient.App.Bsky.Graph.searchStarterPacksV2(
parameters: AppBskyGraphSearchStarterPacksV2Parameters): ATProtoResponse<AppBskyGraphSearchStarterPacksV2Output> {
    val endpoint = "app.bsky.graph.searchStarterPacksV2"

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
