// Lexicon: 1, ID: app.bsky.graph.getActorStarterPacks
// Get a list of starter packs created by the actor.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetActorStarterPacksDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getActorStarterPacks"
}

@Serializable
    data class AppBskyGraphGetActorStarterPacksParameters(
        @SerialName("actor")
        val actor: ATIdentifier,        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetActorStarterPacksOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("starterPacks")
        val starterPacks: List<AppBskyGraphDefsStarterPackViewBasic>    )

/**
 * Get a list of starter packs created by the actor.
 *
 * Endpoint: app.bsky.graph.getActorStarterPacks
 */
suspend fun ATProtoClient.App.Bsky.Graph.getActorStarterPacks(
parameters: AppBskyGraphGetActorStarterPacksParameters): ATProtoResponse<AppBskyGraphGetActorStarterPacksOutput> {
    val endpoint = "app.bsky.graph.getActorStarterPacks"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
