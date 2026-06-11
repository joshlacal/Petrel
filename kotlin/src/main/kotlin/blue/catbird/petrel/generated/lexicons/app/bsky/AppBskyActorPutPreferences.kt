// Lexicon: 1, ID: app.bsky.actor.putPreferences
// Set the private preferences attached to the account.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyActorPutPreferencesDefs {
    const val TYPE_IDENTIFIER = "app.bsky.actor.putPreferences"
}

@Serializable
    data class AppBskyActorPutPreferencesInput(
        @SerialName("preferences")
        val preferences: AppBskyActorDefsPreferences    )

/**
 * Set the private preferences attached to the account.
 *
 * Endpoint: app.bsky.actor.putPreferences
 */
suspend fun ATProtoClient.App.Bsky.Actor.putPreferences(
input: AppBskyActorPutPreferencesInput): ATProtoResponse<Unit> {
    val endpoint = "app.bsky.actor.putPreferences"

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
