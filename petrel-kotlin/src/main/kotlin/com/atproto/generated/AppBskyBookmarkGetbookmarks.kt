// Lexicon: 1, ID: app.bsky.bookmark.getBookmarks
// Gets views of records bookmarked by the authenticated user. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyBookmarkGetbookmarks {
    const val TYPE_IDENTIFIER = "app.bsky.bookmark.getBookmarks"

    @Serializable
    data class Parameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

        @Serializable
    data class Output(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("bookmarks")
        val bookmarks: List<AppBskyBookmarkDefs.Bookmarkview>    )

}

/**
 * Gets views of records bookmarked by the authenticated user. Requires authentication.
 *
 * Endpoint: app.bsky.bookmark.getBookmarks
 */
suspend fun ATProtoClient.App.Bsky.Bookmark.getbookmarks(
parameters: AppBskyBookmarkGetbookmarks.Parameters): ATProtoResponse<AppBskyBookmarkGetbookmarks.Output> {
    val endpoint = "app.bsky.bookmark.getBookmarks"

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
