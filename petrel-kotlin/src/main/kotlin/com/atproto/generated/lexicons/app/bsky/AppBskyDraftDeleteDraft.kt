// Lexicon: 1, ID: app.bsky.draft.deleteDraft
// Deletes a draft by ID. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyDraftDeleteDraftDefs {
    const val TYPE_IDENTIFIER = "app.bsky.draft.deleteDraft"
}

@Serializable
    data class AppBskyDraftDeleteDraftInput(
        @SerialName("id")
        val id: String    )

/**
 * Deletes a draft by ID. Requires authentication.
 *
 * Endpoint: app.bsky.draft.deleteDraft
 */
suspend fun ATProtoClient.App.Bsky.Draft.deleteDraft(
input: AppBskyDraftDeleteDraftInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.draft.deleteDraft"

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
            "Accept" to "None"
        ),
        body = body
    )
}
