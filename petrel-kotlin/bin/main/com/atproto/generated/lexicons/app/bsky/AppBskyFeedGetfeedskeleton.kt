// Lexicon: 1, ID: app.bsky.feed.getFeedSkeleton
// Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetFeedSkeletonDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getFeedSkeleton"
}

@Serializable
    data class AppBskyFeedGetFeedSkeletonParameters(
// Reference to feed generator record describing the specific feed being requested.        @SerialName("feed")
        val feed: ATProtocolURI,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetFeedSkeletonOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("feed")
        val feed: List<AppBskyFeedDefsSkeletonFeedPost>,// Unique identifier per request that may be passed back alongside interactions.        @SerialName("reqId")
        val reqId: String? = null    )

sealed class AppBskyFeedGetFeedSkeletonError(val name: String, val description: String?) {
        object UnknownFeed: AppBskyFeedGetFeedSkeletonError("UnknownFeed", "")
    }

/**
 * Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.
 *
 * Endpoint: app.bsky.feed.getFeedSkeleton
 */
suspend fun ATProtoClient.App.Bsky.Feed.getFeedSkeleton(
parameters: AppBskyFeedGetFeedSkeletonParameters): ATProtoResponse<AppBskyFeedGetFeedSkeletonOutput> {
    val endpoint = "app.bsky.feed.getFeedSkeleton"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
