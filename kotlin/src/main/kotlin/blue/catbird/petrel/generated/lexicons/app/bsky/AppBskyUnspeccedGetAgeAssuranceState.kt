// Lexicon: 1, ID: app.bsky.unspecced.getAgeAssuranceState
// Returns the current state of the age assurance process for an account. This is used to check if the user has completed age assurance or if further action is required.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyUnspeccedGetAgeAssuranceStateDefs {
    const val TYPE_IDENTIFIER = "app.bsky.unspecced.getAgeAssuranceState"
}

    typealias AppBskyUnspeccedGetAgeAssuranceStateOutput = AppBskyUnspeccedDefsAgeAssuranceState

/**
 * Returns the current state of the age assurance process for an account. This is used to check if the user has completed age assurance or if further action is required.
 *
 * Endpoint: app.bsky.unspecced.getAgeAssuranceState
 */
suspend fun ATProtoClient.App.Bsky.Unspecced.getAgeAssuranceState(
): ATProtoResponse<AppBskyUnspeccedGetAgeAssuranceStateOutput> {
    val endpoint = "app.bsky.unspecced.getAgeAssuranceState"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
