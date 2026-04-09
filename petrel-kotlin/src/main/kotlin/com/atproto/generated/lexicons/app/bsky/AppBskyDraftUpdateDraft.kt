// Lexicon: 1, ID: app.bsky.draft.updateDraft
// Updates a draft using private storage (stash). If the draft ID points to a non-existing ID, the update will be silently ignored. This is done because updates don't enforce draft limit, so it accepts all writes, but will ignore invalid ones. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyDraftUpdateDraftDefs {
    const val TYPE_IDENTIFIER = "app.bsky.draft.updateDraft"
}

@Serializable
    data class AppBskyDraftUpdateDraftInput(
        @SerialName("draft")
        val draft: AppBskyDraftDefsDraftWithId    )

/**
 * Updates a draft using private storage (stash). If the draft ID points to a non-existing ID, the update will be silently ignored. This is done because updates don't enforce draft limit, so it accepts all writes, but will ignore invalid ones. Requires authentication.
 *
 * Endpoint: app.bsky.draft.updateDraft
 */
suspend fun ATProtoClient.App.Bsky.Draft.updateDraft(
input: AppBskyDraftUpdateDraftInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.draft.updateDraft"

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
