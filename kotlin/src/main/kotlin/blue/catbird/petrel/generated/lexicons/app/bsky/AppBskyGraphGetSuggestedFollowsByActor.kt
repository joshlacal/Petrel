// Lexicon: 1, ID: app.bsky.graph.getSuggestedFollowsByActor
// Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyGraphGetSuggestedFollowsByActorDefs {
    const val TYPE_IDENTIFIER = "app.bsky.graph.getSuggestedFollowsByActor"
}

@Serializable
    data class AppBskyGraphGetSuggestedFollowsByActorParameters(
        @SerialName("actor")
        val actor: ATIdentifier    )

    @Serializable
    data class AppBskyGraphGetSuggestedFollowsByActorOutput(
        @SerialName("suggestions")
        val suggestions: List<AppBskyActorDefsProfileView>,// Snowflake for this recommendation, use when submitting recommendation events.        @SerialName("recIdStr")
        val recIdStr: String? = null,// DEPRECATED, unused. Previously: if true, response has fallen-back to generic results, and is not scoped using relativeToDid        @SerialName("isFallback")
        val isFallback: Boolean? = null,// DEPRECATED: use recIdStr instead.        @SerialName("recId")
        val recId: Int? = null    )

/**
 * Enumerates follows similar to a given account (actor). Expected use is to recommend additional accounts immediately after following one account.
 *
 * Endpoint: app.bsky.graph.getSuggestedFollowsByActor
 */
suspend fun ATProtoClient.App.Bsky.Graph.getSuggestedFollowsByActor(
parameters: AppBskyGraphGetSuggestedFollowsByActorParameters): ATProtoResponse<AppBskyGraphGetSuggestedFollowsByActorOutput> {
    val endpoint = "app.bsky.graph.getSuggestedFollowsByActor"

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
