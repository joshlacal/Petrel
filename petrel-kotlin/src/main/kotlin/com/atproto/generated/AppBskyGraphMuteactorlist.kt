// Lexicon: 1, ID: app.bsky.graph.muteActorList
// Creates a mute relationship for the specified list of accounts. Mutes are private in Bluesky. Requires auth.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*

object AppBskyGraphMuteactorlist {
    const val TYPE_IDENTIFIER = "app.bsky.graph.muteActorList"

    @Serializable
    data class Input(
        @SerialName("list")
        val list: ATProtocolURI    )

}

/**
 * Creates a mute relationship for the specified list of accounts. Mutes are private in Bluesky. Requires auth.
 *
 * Endpoint: app.bsky.graph.muteActorList
 */
suspend fun ATProtoClient.App.Bsky.Graph.muteactorlist(
input: AppBskyGraphMuteactorlist.Input): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.muteActorList"

    // JSON serialization
    val body = Json.encodeToString(input)
    val contentType = "application/json"

    return networkService.performRequest(
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
