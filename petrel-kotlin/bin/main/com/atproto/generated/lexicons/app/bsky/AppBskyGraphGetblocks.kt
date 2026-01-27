// Lexicon: 1, ID: app.bsky.graph.getBlocks
// Enumerates which accounts the requesting account is currently blocking. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetBlocksDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getBlocks"
}

@Serializable
    data class AppBskyGraphGetBlocksParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetBlocksOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("blocks")
        val blocks: List<AppBskyActorDefsProfileView>    )

/**
 * Enumerates which accounts the requesting account is currently blocking. Requires auth.
 *
 * Endpoint: app.bsky.graph.getBlocks
 */
suspend fun ATProtoClient.App.Bsky.Graph.getBlocks(
parameters: AppBskyGraphGetBlocksParameters): ATProtoResponse<AppBskyGraphGetBlocksOutput> {
    val endpoint = "app.bsky.graph.getBlocks"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
