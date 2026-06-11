// Lexicon: 1, ID: app.bsky.graph.getActorStarterPacks
// Get a list of starter packs created by the actor.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
