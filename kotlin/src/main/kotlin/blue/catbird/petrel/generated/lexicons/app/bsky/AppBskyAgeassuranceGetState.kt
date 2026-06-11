// Lexicon: 1, ID: app.bsky.ageassurance.getState
// Returns server-computed Age Assurance state, if available, and any additional metadata needed to compute Age Assurance state client-side.
package blue.catbird.petrel.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import blue.catbird.petrel.core.types.*
import blue.catbird.petrel.core.*
import blue.catbird.petrel.client.*
import blue.catbird.petrel.network.*
import blue.catbird.petrel.runtime.subscription.openSubscription
import kotlinx.coroutines.flow.*

object AppBskyAgeassuranceGetStateDefs {
    const val TYPE_IDENTIFIER = "app.bsky.ageassurance.getState"
}

@Serializable
    data class AppBskyAgeassuranceGetStateParameters(
        @SerialName("countryCode")
        val countryCode: String,        @SerialName("regionCode")
        val regionCode: String? = null    )

    @Serializable
    data class AppBskyAgeassuranceGetStateOutput(
        @SerialName("state")
        val state: AppBskyAgeassuranceDefsState,        @SerialName("metadata")
        val metadata: AppBskyAgeassuranceDefsStateMetadata    )

/**
 * Returns server-computed Age Assurance state, if available, and any additional metadata needed to compute Age Assurance state client-side.
 *
 * Endpoint: app.bsky.ageassurance.getState
 */
suspend fun ATProtoClient.App.Bsky.Ageassurance.getState(
parameters: AppBskyAgeassuranceGetStateParameters): ATProtoResponse<AppBskyAgeassuranceGetStateOutput> {
    val endpoint = "app.bsky.ageassurance.getState"

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
