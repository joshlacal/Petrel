// Lexicon: 1, ID: app.bsky.feed.getLikes
// Get like records which reference a subject (by AT-URI and CID).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyFeedGetLikesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getLikes"
}

    @Serializable
    data class AppBskyFeedGetLikesLike(
        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("actor")
        val actor: AppBskyActorDefsProfileView    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#appBskyFeedGetLikesLike"
        }
    }

@Serializable
    data class AppBskyFeedGetLikesParameters(
// AT-URI of the subject (eg, a post record).        @SerialName("uri")
        val uri: ATProtocolURI,// CID of the subject record (aka, specific version of record), to filter likes.        @SerialName("cid")
        val cid: CID? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyFeedGetLikesOutput(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("likes")
        val likes: List<AppBskyFeedGetLikesLike>    )

/**
 * Get like records which reference a subject (by AT-URI and CID).
 *
 * Endpoint: app.bsky.feed.getLikes
 */
suspend fun ATProtoClient.App.Bsky.Feed.getLikes(
parameters: AppBskyFeedGetLikesParameters): ATProtoResponse<AppBskyFeedGetLikesOutput> {
    val endpoint = "app.bsky.feed.getLikes"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
