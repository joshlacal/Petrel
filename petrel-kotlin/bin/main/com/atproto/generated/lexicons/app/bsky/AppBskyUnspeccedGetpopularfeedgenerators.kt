// Lexicon: 1, ID: app.bsky.unspecced.getPopularFeedGenerators
// An unspecced view of globally popular feed generators.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
