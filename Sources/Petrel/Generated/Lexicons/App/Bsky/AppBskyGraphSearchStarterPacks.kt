// Lexicon: 1, ID: app.bsky.graph.searchStarterPacks
// Find starter packs matching search criteria. Does not require auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphSearchStarterPacksDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.searchStarterPacks"
}

@Serializable
    data class AppBskyGraphSearchStarterPacksParameters(
// Search query string. Syntax, phrase, boolean, and faceting is unspecified, but Lucene query syntax is recommended.        @SerialName("q")
        val q: String,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphSearchStarterPacksOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefsStarterPackViewBasic>    )

/**
 * Find starter packs matching search criteria. Does not require auth.
 *
 * Endpoint: app.bsky.graph.searchStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Graph.searchStarterPacks(
parameters: AppBskyGraphSearchStarterPacksParameters): ATProtoResponse<AppBskyGraphSearchStarterPacksOutput> {
    val endpoint = "app.bsky.graph.searchStarterPacks"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
