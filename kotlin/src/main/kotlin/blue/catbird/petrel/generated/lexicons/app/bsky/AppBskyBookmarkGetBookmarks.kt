// Lexicon: 1, ID: app.bsky.bookmark.getBookmarks
// Gets views of records bookmarked by the authenticated user. Requires authentication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
