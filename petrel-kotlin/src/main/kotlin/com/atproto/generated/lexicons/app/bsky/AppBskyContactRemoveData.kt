// Lexicon: 1, ID: app.bsky.contact.removeData
// Removes all stored hashes used for contact matching, existing matches, and sync status. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyContactRemoveDataDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.removeData"
}

@Serializable
    class AppBskyContactRemoveDataInput

    @Serializable
    class AppBskyContactRemoveDataOutput

sealed class AppBskyContactRemoveDataError(val name: String, val description: String?) {
        object InvalidDid: AppBskyContactRemoveDataError("InvalidDid", "")
        object InternalError: AppBskyContactRemoveDataError("InternalError", "")
    }

/**
 * Removes all stored hashes used for contact matching, existing matches, and sync status. Requires authentication.
 *
 * Endpoint: app.bsky.contact.removeData
 */
suspend fun ATProtoClient.App.Bsky.Contact.removeData(
input: AppBskyContactRemoveDataInput): ATProtoResponse<AppBskyContactRemoveDataOutput> {
    val endpoint = "app.bsky.contact.removeData"

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
            "Accept" to "application/json"
        ),
        body = body
    )
}
