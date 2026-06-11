// Lexicon: 1, ID: app.bsky.feed.getRepostedBy
// Get a list of reposts for a given post.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyFeedGetRepostedByDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getRepostedBy"
}

@Serializable
    data class AppBskyFeedGetRepostedByParameters(
// Reference (AT-URI) of post record        @SerialName("uri")
        val uri: ATProtocolURI,// If supplied, filters to reposts of specific version (by CID) of the post record.        @SerialName("cid")
        val cid: CID? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetRepostedByOutput(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("repostedBy")
        val repostedBy: List<AppBskyActorDefsProfileView>    )

/**
 * Get a list of reposts for a given post.
 *
 * Endpoint: app.bsky.feed.getRepostedBy
 */
suspend fun ATProtoClient.App.Bsky.Feed.getRepostedBy(
parameters: AppBskyFeedGetRepostedByParameters): ATProtoResponse<AppBskyFeedGetRepostedByOutput> {
    val endpoint = "app.bsky.feed.getRepostedBy"

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
