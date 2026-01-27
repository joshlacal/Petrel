// Lexicon: 1, ID: app.bsky.graph.getMutes
// Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphGetMutesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getMutes"
}

@Serializable
    data class AppBskyGraphGetMutesParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetMutesOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("mutes")
        val mutes: List<AppBskyActorDefsProfileView>    )

/**
 * Enumerates accounts that the requesting account (actor) currently has muted. Requires auth.
 *
 * Endpoint: app.bsky.graph.getMutes
 */
suspend fun ATProtoClient.App.Bsky.Graph.getMutes(
parameters: AppBskyGraphGetMutesParameters): ATProtoResponse<AppBskyGraphGetMutesOutput> {
    val endpoint = "app.bsky.graph.getMutes"

    val queryParams = parameters.toQueryParams()

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryParams = queryParams,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
