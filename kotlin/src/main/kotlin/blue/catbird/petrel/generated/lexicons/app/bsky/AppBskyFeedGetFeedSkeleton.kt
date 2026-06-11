// Lexicon: 1, ID: app.bsky.feed.getFeedSkeleton
// Get a skeleton of a feed provided by a feed generator. Auth is optional, depending on provider requirements, and provides the DID of the requester. Implemented by Feed Generator Service.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
