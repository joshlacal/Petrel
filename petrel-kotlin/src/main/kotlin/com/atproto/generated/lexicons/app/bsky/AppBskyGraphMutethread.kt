// Lexicon: 1, ID: app.bsky.graph.muteThread
// Mutes a thread preventing notifications from the thread and any of its children. Mutes are private in Bluesky. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
import kotlinx.coroutines.flow.*

object AppBskyGraphMuteThreadDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.muteThread"
}

@Serializable
    data class AppBskyGraphMuteThreadInput(
        @SerialName("root")
        val root: ATProtocolURI    )

/**
 * Mutes a thread preventing notifications from the thread and any of its children. Mutes are private in Bluesky. Requires auth.
 *
 * Endpoint: app.bsky.graph.muteThread
 */
suspend fun ATProtoClient.App.Bsky.Graph.muteThread(
input: AppBskyGraphMuteThreadInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.muteThread"

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
