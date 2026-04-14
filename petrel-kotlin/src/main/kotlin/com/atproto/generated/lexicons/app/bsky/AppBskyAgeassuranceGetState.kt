// Lexicon: 1, ID: app.bsky.ageassurance.getState
// Returns server-computed Age Assurance state, if available, and any additional metadata needed to compute Age Assurance state client-side.
package com.atproto.generated

import kotlinx.serialization.*
import kotlinx.serialization.json.*
import com.atproto.core.types.*
import com.atproto.core.*
import com.atproto.client.*
import com.atproto.network.*
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
