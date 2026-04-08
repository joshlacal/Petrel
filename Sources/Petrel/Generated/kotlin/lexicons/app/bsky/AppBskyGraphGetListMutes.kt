// Lexicon: 1, ID: app.bsky.graph.getListMutes
// Enumerates mod lists that the requesting account (actor) currently has muted. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetListMutesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getListMutes"
}

@Serializable
    data class AppBskyGraphGetListMutesParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetListMutesOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("lists")
        val lists: List<AppBskyGraphDefsListView>    )

/**
 * Enumerates mod lists that the requesting account (actor) currently has muted. Requires auth.
 *
 * Endpoint: app.bsky.graph.getListMutes
 */
suspend fun ATProtoClient.App.Bsky.Graph.getListMutes(
parameters: AppBskyGraphGetListMutesParameters): ATProtoResponse<AppBskyGraphGetListMutesOutput> {
    val endpoint = "app.bsky.graph.getListMutes"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
