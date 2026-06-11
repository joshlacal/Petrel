// Lexicon: 1, ID: app.bsky.unspecced.getTrends
// Get the current trends on the network
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetTrendsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getTrends"
}

@Serializable
    data class AppBskyUnspeccedGetTrendsParameters(
        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetTrendsOutput(
        @SerialName("trends")
        val trends: List<AppBskyUnspeccedDefsTrendView>    )

/**
 * Get the current trends on the network
 *
 * Endpoint: app.bsky.unspecced.getTrends
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getTrends(
parameters: AppBskyUnspeccedGetTrendsParameters): ATProtoResponse<AppBskyUnspeccedGetTrendsOutput> {
    val endpoint = "app.bsky.unspecced.getTrends"

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
