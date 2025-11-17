// Lexicon: 1, ID: app.bsky.feed.describeFeedGenerator
// Get information about a feed generator, including policies and offered feed URIs. Does not require auth; implemented by Feed Generator services (not App View).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedDescribefeedgenerator {
    const val TYPE_IDENTIFIER = "app.bsky.feed.describeFeedGenerator"

        @Serializable
    data class Output(
        @SerialName("did")
        val did: DID,        @SerialName("feeds")
        val feeds: List<Feed>,        @SerialName("links")
        val links: Links? = null    )

        @Serializable
    data class Feed(
        @SerialName("uri")
        val uri: ATProtocolURI    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#feed"
        }
    }

    @Serializable
    data class Links(
        @SerialName("privacyPolicy")
        val privacyPolicy: String?,        @SerialName("termsOfService")
        val termsOfService: String?    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#links"
        }
    }

}

/**
 * Get information about a feed generator, including policies and offered feed URIs. Does not require auth; implemented by Feed Generator services (not App View).
 *
 * Endpoint: app.bsky.feed.describeFeedGenerator
 */
suspend fun ATProtoClient.App.Bsky.Feed.describefeedgenerator(
): ATProtoResponse<AppBskyFeedDescribefeedgenerator.Output> {
    val endpoint = "app.bsky.feed.describeFeedGenerator"

    val queryParams: Map<String, String>? = null

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
