// Lexicon: 1, ID: app.bsky.graph.muteActor
// Creates a mute relationship for the specified account. Mutes are private in Bluesky. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "POST",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf(
            "Content-Type" to contentType,
            "Accept" to "None"
        ),
        body = body
    )
}
