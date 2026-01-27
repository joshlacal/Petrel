// Lexicon: 1, ID: app.bsky.graph.getStarterPacks
// Get views for a list of starter packs.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetStarterPacksDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getStarterPacks"
}

@Serializable
    data class AppBskyGraphGetStarterPacksParameters(
        @SerialName("uris")
        val uris: List<ATProtocolURI>    )

    @Serializable
    data class AppBskyGraphGetStarterPacksOutput(
        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefsStarterPackViewBasic>    )

/**
 * Get views for a list of starter packs.
 *
 * Endpoint: app.bsky.graph.getStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Graph.getStarterPacks(
parameters: AppBskyGraphGetStarterPacksParameters): ATProtoResponse<AppBskyGraphGetStarterPacksOutput> {
    val endpoint = "app.bsky.graph.getStarterPacks"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
