// Lexicon: 1, ID: app.bsky.graph.unmuteActorList
// Unmutes the specified list of accounts. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphUnmuteActorListDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.unmuteActorList"
}

@Serializable
    data class AppBskyGraphUnmuteActorListInput(
        @SerialName("list")
        val list: ATProtocolURI    )

/**
 * Unmutes the specified list of accounts. Requires auth.
 *
 * Endpoint: app.bsky.graph.unmuteActorList
 */
suspend fun ATProtoClient.App.Bsky.Graph.unmuteActorList(
input: AppBskyGraphUnmuteActorListInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.unmuteActorList"

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
