// Lexicon: 1, ID: app.bsky.feed.getLikes
// Get like records which reference a subject (by AT-URI and CID).
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyFeedGetlikes {
    const val TYPE_IDENTIFIER = "app.bsky.feed.getLikes"

    @Serializable
    data class Parameters(
// AT-URI of the subject (eg, a post record).        @SerialName("uri")
        val uri: ATProtocolURI,// CID of the subject record (aka, specific version of record), to filter likes.        @SerialName("cid")
        val cid: CID? = null,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID? = null,        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("likes")
        val likes: List<Like>    )

        @Serializable
    data class Like(
        @SerialName("indexedAt")
        val indexedAt: ATProtocolDate,        @SerialName("createdAt")
        val createdAt: ATProtocolDate,        @SerialName("actor")
        val actor: AppBskyActorDefs.Profileview    ) {
        companion object {
            const val TYPE_IDENTIFIER = "#like"
        }
    }

}

/**
 * Get like records which reference a subject (by AT-URI and CID).
 *
 * Endpoint: app.bsky.feed.getLikes
 */
suspend fun ATProtoClient.App.Bsky.Feed.getlikes(
parameters: AppBskyFeedGetlikes.Parameters): ATProtoResponse<AppBskyFeedGetlikes.Output> {
    val endpoint = "app.bsky.feed.getLikes"

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
