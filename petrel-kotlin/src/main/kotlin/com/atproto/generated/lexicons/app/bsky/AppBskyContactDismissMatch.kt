// Lexicon: 1, ID: app.bsky.contact.dismissMatch
// Removes a match that was found via contact import. It shouldn't appear again if the same contact is re-imported. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyContactDismissMatchDefs {
    const val TYPE_IDENTIFIER = "app.bsky.contact.dismissMatch"
}

@Serializable
    data class AppBskyContactDismissMatchInput(
// The subject's DID to dismiss the match with.        @SerialName("subject")
        val subject: DID    )

    @Serializable
    class AppBskyContactDismissMatchOutput

sealed class AppBskyContactDismissMatchError(val name: String, val description: String?) {
        object InvalidDid: AppBskyContactDismissMatchError("InvalidDid", "")
        object InternalError: AppBskyContactDismissMatchError("InternalError", "")
    }

/**
 * Removes a match that was found via contact import. It shouldn't appear again if the same contact is re-imported. Requires authentication.
 *
 * Endpoint: app.bsky.contact.dismissMatch
 */
suspend fun ATProtoClient.App.Bsky.Contact.dismissMatch(
input: AppBskyContactDismissMatchInput): ATProtoResponse<AppBskyContactDismissMatchOutput> {
    val endpoint = "app.bsky.contact.dismissMatch"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    val queryParams: Map<String, String>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "application/json"
        ),
        body = body
    )
}
