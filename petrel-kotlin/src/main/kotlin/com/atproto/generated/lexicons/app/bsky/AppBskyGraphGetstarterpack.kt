// Lexicon: 1, ID: app.bsky.graph.getStarterPack
// Gets a view of a starter pack.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetStarterPackDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getStarterPack"
}

@Serializable
    data class AppBskyGraphGetStarterPackParameters(
// Reference (AT-URI) of the starter pack record.        @SerialName("starterPack")
        val starterPack: ATProtocolURI    )

    @Serializable
    data class AppBskyGraphGetStarterPackOutput(
        @SerialName("starterPack")
        val starterPack: AppBskyGraphDefsStarterPackView    )

/**
 * Gets a view of a starter pack.
 *
 * Endpoint: app.bsky.graph.getStarterPack
 */
suspend fun ATProtoClient.App.Bsky.Graph.getStarterPack(
parameters: AppBskyGraphGetStarterPackParameters): ATProtoResponse<AppBskyGraphGetStarterPackOutput> {
    val endpoint = "app.bsky.graph.getStarterPack"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
