// Lexicon: 1, ID: app.bsky.graph.unmuteThread
// Unmutes the specified thread. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphUnmuteThreadDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.unmuteThread"
}

@Serializable
    data class AppBskyGraphUnmuteThreadInput(
        @SerialName("root")
        val root: ATProtocolURI    )

/**
 * Unmutes the specified thread. Requires auth.
 *
 * Endpoint: app.bsky.graph.unmuteThread
 */
suspend fun ATProtoClient.App.Bsky.Graph.unmuteThread(
input: AppBskyGraphUnmuteThreadInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.unmuteThread"

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
