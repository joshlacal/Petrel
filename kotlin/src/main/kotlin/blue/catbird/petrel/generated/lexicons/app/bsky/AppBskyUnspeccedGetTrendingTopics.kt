// Lexicon: 1, ID: app.bsky.unspecced.getTrendingTopics
// Get a list of trending topics
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetTrendingTopicsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getTrendingTopics"
}

@Serializable
    data class AppBskyUnspeccedGetTrendingTopicsParameters(
// DID of the account making the request (not included for public/unauthenticated queries). Used to boost followed accounts in ranking.        @SerialName("viewer")
        val viewer: DID? = null,        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetTrendingTopicsOutput(
        @SerialName("topics")
        val topics: List<AppBskyUnspeccedDefsTrendingTopic>,        @SerialName("suggested")
        val suggested: List<AppBskyUnspeccedDefsTrendingTopic>    )

/**
 * Get a list of trending topics
 *
 * Endpoint: app.bsky.unspecced.getTrendingTopics
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getTrendingTopics(
parameters: AppBskyUnspeccedGetTrendingTopicsParameters): ATProtoResponse<AppBskyUnspeccedGetTrendingTopicsOutput> {
    val endpoint = "app.bsky.unspecced.getTrendingTopics"

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
