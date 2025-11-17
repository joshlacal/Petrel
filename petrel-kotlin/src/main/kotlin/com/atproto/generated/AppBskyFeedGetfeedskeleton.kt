// Lexicon: 1, ID: app.bsky.feed.getFeedSkeleton
// Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetfeedskeleton {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeedSkeleton"

    @Serializable
    data class Parameters(
// Reference to feed generator record describing the specific feed being requested.        @SerialName("feed")
        val feed: ATProtocolURI,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefs.Skeletonfeedpost>,// Unique identifier per request that may be passed back alongside interactions.        @SerialName("reqId")
        val reqId: String? = null    )

    sealed class Error(val name: String, val description: String?) {
        object Unknownfeed: Error("UnknownFeed", "")
    }

}

/**
 * Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.
 *
 * Endpoint: app.bsky.feed.getFeedSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Feed.getfeedskeleton(
parameters: AppBskyFeedGetfeedskeleton.Parameters): ATProtoResponse<AppBskyFeedGetfeedskeleton.Output> {
    val endpoint = "app.bsky.feed.getFeedSkeleton"

    val queryParams = buildMap<String, String> {
        // Convert parameters to query string
        // This would use reflection or a custom serializer
    }

    return networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
