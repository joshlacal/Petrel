// Lexicon: 1, ID: app.bsky.unspecced.getSuggestedStarterPacks
// Get a list of suggested starterpacks
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetSuggestedStarterPacksDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getSuggestedStarterPacks"
}

@Serializable
    data class AppBskyUnspeccedGetSuggestedStarterPacksParameters(
        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetSuggestedStarterPacksOutput(
        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefsStarterPackView>    )

/**
 * Get a list of suggested starterpacks
 *
 * Endpoint: app.bsky.unspecced.getSuggestedStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getSuggestedStarterPacks(
parameters: AppBskyUnspeccedGetSuggestedStarterPacksParameters): ATProtoResponse<AppBskyUnspeccedGetSuggestedStarterPacksOutput> {
    val endpoint = "app.bsky.unspecced.getSuggestedStarterPacks"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
