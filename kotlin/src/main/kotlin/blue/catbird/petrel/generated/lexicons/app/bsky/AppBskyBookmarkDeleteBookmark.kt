// Lexicon: 1, ID: app.bsky.bookmark.deleteBookmark
// Deletes a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyBookmarkDeleteBookmarkDefs {
    const val TYPE_IDENTIFIER = "app.bsky.bookmark.deleteBookmark"
}

@Serializable
    data class AppBskyBookmarkDeleteBookmarkInput(
        @SerialName("uri")
        val uri: ATProtocolURI    )

sealed class AppBskyBookmarkDeleteBookmarkError(val name: String, val description: String?) {
        object UnsupportedCollection: AppBskyBookmarkDeleteBookmarkError("UnsupportedCollection", "The URI to be bookmarked is for an unsupported collection.")
    }

/**
 * Deletes a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.
 *
 * Endpoint: app.bsky.bookmark.deleteBookmark
 */
suspend fun ATProtoClient.App.Bsky.Bookmark.deleteBookmark(
input: AppBskyBookmarkDeleteBookmarkInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.bookmark.deleteBookmark"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
