// Lexicon: 1, ID: app.bsky.graph.muteActorList
// Creates a mute relationship for the specified list of accounts. Mutes are private in Bluesky. Requires auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphMuteActorListDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.muteActorList"
}

@Serializable
    data class AppBskyGraphMuteActorListInput(
        @SerialName("list")
        val list: ATProtocolURI    )

/**
 * Creates a mute relationship for the specified list of accounts. Mutes are private in Bluesky. Requires auth.
 *
 * Endpoint: app.bsky.graph.muteActorList
 */
suspend fun ATProtoClient.App.Bsky.Graph.muteActorList(
input: AppBskyGraphMuteActorListInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.graph.muteActorList"

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
