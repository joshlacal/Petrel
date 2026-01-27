// Lexicon: 1, ID: app.bsky.bookmark.createBookmark
// Creates a private bookmark for the specified record. Currently, only `app.bsky.feed.post` records are supported. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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
