// Lexicon: 1, ID: app.bsky.graph.getBlocks
// Enumerates which accounts the requesting account is currently blocking. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphGetBlocksDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getBlocks"
}

@Serializable
    data class AppBskyGraphGetBlocksParameters(
        @SerialName("limit")
        val limit: Int? = null,        @SerialName("cursor")
        val cursor: String? = null    )

    @Serializable
    data class AppBskyGraphGetBlocksOutput(
        @SerialName("cursor")
        val cursor: String? = null,        @SerialName("blocks")
        val blocks: List<AppBskyActorDefsProfileView>    )

/**
 * Enumerates which accounts the requesting account is currently blocking. Requires auth.
 *
 * Endpoint: app.bsky.graph.getBlocks
 */
suspend fun ATProtoClient.App.Bsky.Graph.getBlocks(
parameters: AppBskyGraphGetBlocksParameters): ATProtoResponse<AppBskyGraphGetBlocksOutput> {
    val endpoint = "app.bsky.graph.getBlocks"

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
