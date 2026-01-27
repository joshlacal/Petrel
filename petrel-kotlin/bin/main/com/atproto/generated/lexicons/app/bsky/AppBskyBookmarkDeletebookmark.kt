// Lexicon: 1, ID: app.bsky.bookmark.deleteBookmark
// Deletes a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
