// Lexicon: 1, ID: app.bsky.unspecced.getPopularFeedGenerators
// An unspecced view of globally popular feed generators.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetPopularFeedGeneratorsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getPopularFeedGenerators"
}

@Serializable
    data class AppBskyUnspeccedGetPopularFeedGeneratorsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("query")
        val query: String? = null    )

    @Serializable
    data class AppBskyUnspeccedGetPopularFeedGeneratorsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>    )

/**
 * An unspecced view of globally popular feed generators.
 *
 * Endpoint: app.bsky.unspecced.getPopularFeedGenerators
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getPopularFeedGenerators(
parameters: AppBskyUnspeccedGetPopularFeedGeneratorsParameters): ATProtoResponse<AppBskyUnspeccedGetPopularFeedGeneratorsOutput> {
    val endpoint = "app.bsky.unspecced.getPopularFeedGenerators"

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
