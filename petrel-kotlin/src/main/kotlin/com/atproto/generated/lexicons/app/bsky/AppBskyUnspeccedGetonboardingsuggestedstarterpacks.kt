// Lexicon: 1, ID: app.bsky.unspecced.getOnboardingSuggestedStarterPacks
// Get a list of suggested starterpacks for onboarding
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetOnboardingSuggestedStarterPacksDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getOnboardingSuggestedStarterPacks"
}

@Serializable
    data class AppBskyUnspeccedGetOnboardingSuggestedStarterPacksParameters(
        @SerialName("limit")
        val limit: Int? = null    )

    @Serializable
    data class AppBskyUnspeccedGetOnboardingSuggestedStarterPacksOutput(
        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefsStarterPackView>    )

/**
 * Get a list of suggested starterpacks for onboarding
 *
 * Endpoint: app.bsky.unspecced.getOnboardingSuggestedStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getOnboardingSuggestedStarterPacks(
parameters: AppBskyUnspeccedGetOnboardingSuggestedStarterPacksParameters): ATProtoResponse<AppBskyUnspeccedGetOnboardingSuggestedStarterPacksOutput> {
    val endpoint = "app.bsky.unspecced.getOnboardingSuggestedStarterPacks"

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
