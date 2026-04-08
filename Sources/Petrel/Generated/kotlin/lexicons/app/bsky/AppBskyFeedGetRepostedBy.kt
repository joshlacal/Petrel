// Lexicon: 1, ID: app.bsky.feed.getRepostedBy
// Get a list of reposts for a given post.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
