// Lexicon: 1, ID: app.bsky.actor.getProfile
// Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyActorGetProfileDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.getProfile"
}

@Serializable
    data class AppBskyActorGetProfileParameters(
// Handle or DID of account to fetch profile of.        @SerialName("actor")
        val actor: ATIdentifier    )

    typealias AppBskyActorGetProfileOutput = AppBskyActorDefsProfileViewDetailed

/**
 * Get detailed profile view of an actor. Does not require auth, but contains relevant metadata with auth.
 *
 * Endpoint: app.bsky.actor.getProfile
 */
suspend fun ATProtoClient.App.Bsky.Actor.getProfile(
parameters: AppBskyActorGetProfileParameters): ATProtoResponse<AppBskyActorGetProfileOutput> {
    val endpoint = "app.bsky.actor.getProfile"

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
