// Lexicon: 1, ID: app.bsky.feed.describeFeedGenerator
// Get information about a feed generator, including policies and offered feed URIs. Does not require auth; implemented by Feed Generator services (not App View).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedDescribeFeedGeneratorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.describeFeedGenerator"
}

    @Serializable
    data class AppBskyFeedDescribeFeedGeneratorFeed(
        @SerialName("uri")
        val uri: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDescribeFeedGeneratorFeed"
        }
    }

    @Serializable
    data class AppBskyFeedDescribeFeedGeneratorLinks(
        @SerialName("privacyPolicy")
        val privacyPolicy: String?,        @SerialName("termsOfService")
        val termsOfService: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedDescribeFeedGeneratorLinks"
        }
    }

    @Serializable
    data class AppBskyFeedDescribeFeedGeneratorOutput(
        @SerialName("did")
        val did: DID,        @SerialName("feeds")
        val feeds: List<AppBskyFeedDescribeFeedGeneratorFeed>,        @SerialName("links")
        val links: AppBskyFeedDescribeFeedGeneratorLinks? = null    )

/**
 * Get information about a feed generator, including policies and offered feed URIs. Does not require auth; implemented by Feed Generator services (not App View).
 *
 * Endpoint: app.bsky.feed.describeFeedGenerator
 */
suspend fun ATProtoClient.App.Bsky.Feed.describeFeedGenerator(
): ATProtoResponse<AppBskyFeedDescribeFeedGeneratorOutput> {
    val endpoint = "app.bsky.feed.describeFeedGenerator"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
