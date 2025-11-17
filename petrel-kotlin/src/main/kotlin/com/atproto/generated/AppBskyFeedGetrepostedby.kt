// Lexicon: 1, ID: app.bsky.feed.getRepostedBy
// Get a list of reposts for a given post.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetrepostedby {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getRepostedBy"

    @Serializable
    data class Parameters(
// Reference (AT-URI) of post record        @SerialName("uri")
        val uri: ATProtocolURI,// If supplied, filters to reposts of specific version (by CID) of the post record.        @SerialName("cid")
        val cid: CID? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("repostedBy")
        val repostedBy: List<AppBskyActorDefs.Profileview>    )

}

/**
 * Get a list of reposts for a given post.
 *
 * Endpoint: app.bsky.feed.getRepostedBy
 */
suspend fun ATProtoClient.App.Bsky.Feed.getrepostedby(
parameters: AppBskyFeedGetrepostedby.Parameters): ATProtoResponse<AppBskyFeedGetrepostedby.Output> {
    val endpoint = "app.bsky.feed.getRepostedBy"

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
