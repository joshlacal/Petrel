// Lexicon: 1, ID: app.bsky.bookmark.createBookmark
// Creates a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyBookmarkCreateBookmarkDefs {
    const val TYPE_IDENTIFIER = "app.bsky.bookmark.createBookmark"
}

@Serializable
    data class AppBskyBookmarkCreateBookmarkInput(
        @SerialName("uri")
        val uri: ATProtocolURI,        @SerialName("cid")
        val cid: CID    )

sealed class AppBskyBookmarkCreateBookmarkError(val name: String, val description: String?) {
        object UnsupportedCollection: AppBskyBookmarkCreateBookmarkError("UnsupportedCollection", "The URI to be bookmarked is for an unsupported collection.")
    }

/**
 * Creates a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.
 *
 * Endpoint: app.bsky.bookmark.createBookmark
 */
suspend fun ATProtoClient.App.Bsky.Bookmark.createBookmark(
input: AppBskyBookmarkCreateBookmarkInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.bookmark.createBookmark"

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
