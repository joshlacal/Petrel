// Lexicon: 1, ID: app.bsky.graph.muteThread
// Mutes a thread preventing notifications from the thread and any of its children. Mutes are private in Bluesky. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
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
