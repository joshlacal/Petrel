// Lexicon: 1, ID: app.bsky.graph.unmuteActor
// Unmutes the specified account. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphUnmuteActorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.unmuteActor"
}

@Serializable
    data class AppBskyGraphUnmuteActorInput(
        @SerialName("actor")
        val actor: ATIdentifier    )

/**
 * Unmutes the specified account. Requires auth.
 *
 * Endpoint: app.bsky.graph.unmuteActor
 */
suspend fun ATProtoClient.App.Bsky.Graph.unmuteActor(
input: AppBskyGraphUnmuteActorInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.unmuteActor"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryParams = null,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
