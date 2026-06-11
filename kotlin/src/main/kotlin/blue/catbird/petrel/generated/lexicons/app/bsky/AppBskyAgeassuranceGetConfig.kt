// Lexicon: 1, ID: app.bsky.ageassurance.getConfig
// Returns Age Assurance configuration for use on the client.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyAgeassuranceGetConfigDefs {
    const val TYPE_IDENTIFIER = "app.bsky.ageassurance.getConfig"
}

    typealias AppBskyAgeassuranceGetConfigOutput = AppBskyAgeassuranceDefsConfig

/**
 * Returns Age Assurance configuration for use on the client.
 *
 * Endpoint: app.bsky.ageassurance.getConfig
 */
suspend fun ATProtoClient.App.Bsky.Ageassurance.getConfig(
): ATProtoResponse<AppBskyAgeassuranceGetConfigOutput> {
    val endpoint = "app.bsky.ageassurance.getConfig"

    val queryItems: List<Pair<String, String>>? = null

    return client.networkService.performRequest(
        method = "GET",
        endpoint = endpoint,
        queryItems = queryItems,
        headers = mapOf("Accept" to "application/json"),
        body = null
    )
}
