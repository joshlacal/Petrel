// Lexicon: 1, ID: app.bsky.unspecced.getTrends
// Get the current trends on the network
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
