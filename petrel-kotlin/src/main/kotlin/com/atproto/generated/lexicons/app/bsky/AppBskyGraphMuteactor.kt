// Lexicon: 1, ID: app.bsky.graph.muteActor
// Creates a mute relationship for the specified account. Mutes are private in Bluesky. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphMuteActorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.muteActor"
}

@Serializable
    data class AppBskyGraphMuteActorInput(
        @SerialName("actor")
        val actor: ATIdentifier    )

/**
 * Creates a mute relationship for the specified account. Mutes are private in Bluesky. Requires auth.
 *
 * Endpoint: app.bsky.graph.muteActor
 */
suspend fun ATProtoClient.App.Bsky.Graph.muteActor(
input: AppBskyGraphMuteActorInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.muteActor"

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
