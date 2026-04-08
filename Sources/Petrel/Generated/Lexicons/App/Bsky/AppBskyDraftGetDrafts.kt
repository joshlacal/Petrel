// Lexicon: 1, ID: app.bsky.draft.getDrafts
// Gets views of user drafts. Requires authentication.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyDraftGetDraftsDefs {
    const val TYPE_IDENTIFIER = "app.bsky.draft.getDrafts"
}

@Serializable
    data class AppBskyDraftGetDraftsParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyDraftGetDraftsOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("drafts")
        val drafts: List<AppBskyDraftDefsDraftView>    )

/**
 * Gets views of user drafts. Requires authentication.
 *
 * Endpoint: app.bsky.draft.getDrafts
 */
suspend fun ATProtoClient.App.Bsky.Draft.getDrafts(
parameters: AppBskyDraftGetDraftsParameters): ATProtoResponse<AppBskyDraftGetDraftsOutput> {
    val endpoint = "app.bsky.draft.getDrafts"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
