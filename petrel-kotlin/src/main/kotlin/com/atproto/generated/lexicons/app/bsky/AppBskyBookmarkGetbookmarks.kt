// Lexicon: 1, ID: app.bsky.bookmark.getBookmarks
// Gets views of records bookmarked by the authenticated user. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyBookmarkGetBookmarksDefs {
    const val TYPE_IDENTIFIER = "app.bsky.bookmark.getBookmarks"
}

@Serializable
    data class AppBskyBookmarkGetBookmarksParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyBookmarkGetBookmarksOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("bookmarks")
        val bookmarks: List<AppBskyBookmarkDefsBookmarkView>    )

/**
 * Gets views of records bookmarked by the authenticated user. Requires authentication.
 *
 * Endpoint: app.bsky.bookmark.getBookmarks
 */
suspend fun ATProtoClient.App.Bsky.Bookmark.getBookmarks(
parameters: AppBskyBookmarkGetBookmarksParameters): ATProtoResponse<AppBskyBookmarkGetBookmarksOutput> {
    val endpoint = "app.bsky.bookmark.getBookmarks"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
