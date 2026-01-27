// Lexicon: 1, ID: app.bsky.feed.getFeedGenerators
// Get information about a list of feed generators.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetFeedGeneratorsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeedGenerators"
}

@Serializable
    data class AppBskyFeedGetFeedGeneratorsParameters(
        @SerialName("feeds")
        val feeds: List<ATProtocolURI>    )

    @Serializable
    data class AppBskyFeedGetFeedGeneratorsOutput(
        @SerialName("feeds")
        val feeds: List<AppBskyFeedDefsGeneratorView>    )

/**
 * Get information about a list of feed generators.
 *
 * Endpoint: app.bsky.feed.getFeedGenerators
 */
suspend fun ATProtoClient.App.Bsky.Feed.getFeedGenerators(
parameters: AppBskyFeedGetFeedGeneratorsParameters): ATProtoResponse<AppBskyFeedGetFeedGeneratorsOutput> {
    val endpoint = "app.bsky.feed.getFeedGenerators"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
