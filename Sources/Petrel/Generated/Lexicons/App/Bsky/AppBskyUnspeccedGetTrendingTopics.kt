// Lexicon: 1, ID: app.bsky.unspecced.getTrendingTopics
// Get a list of trending topics
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
