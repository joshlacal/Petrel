// Lexicon: 1, ID: app.bsky.graph.unmuteActor
// Unmutes the specified account. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
