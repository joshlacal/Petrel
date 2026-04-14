// Lexicon: 1, ID: app.bsky.graph.getListBlocks
// Get mod lists that the requesting account (actor) is blocking. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetListBlocksDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getListBlocks"
}

@Serializable
    data class AppBskyGraphGetListBlocksParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetListBlocksOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("lists")
        val lists: List<AppBskyGraphDefsListView>    )

/**
 * Get mod lists that the requesting account (actor) is blocking. Requires auth.
 *
 * Endpoint: app.bsky.graph.getListBlocks
 */
suspend fun ATProtoClient.App.Bsky.Graph.getListBlocks(
parameters: AppBskyGraphGetListBlocksParameters): ATProtoResponse<AppBskyGraphGetListBlocksOutput> {
    val endpoint = "app.bsky.graph.getListBlocks"

    // List<Pair<String, String>> preserves repeated keys, which ATProto
    // array-valued query params rely on (e.g. `?actors=a&actors=b`).
    val queryItems = parameters.toQueryItems()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
